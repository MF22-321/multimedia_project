#!/usr/bin/env python3
"""Bluetooth/Wi-Fi bootstrap for the embedded Android Auto receiver.

Adapted from LIVI's GPL-3.0-or-later Android Auto wireless driver. This helper
only owns the temporary access point and Wireless Projection Protocol (WPP)
handshake; media continues through the project's Node/C++/Flutter pipeline.
"""

from __future__ import annotations

import os
import signal
import socket
import struct
import subprocess
import sys
import threading
import time
from pathlib import Path

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib


AA_UUID = "4de17a00-52cb-11e6-bdf4-0800200c9a66"
AA_PROFILE_PATH = "/com/multimedia/android_auto/profile"
AA_AGENT_PATH = "/com/multimedia/android_auto/agent"
AA_AD_PATH = "/com/multimedia/android_auto/advertisement"
BLUEZ = "org.bluez"
PROFILE_IFACE = "org.bluez.Profile1"
AGENT_IFACE = "org.bluez.Agent1"
LE_AD_IFACE = "org.bluez.LEAdvertisement1"

SSID = os.environ.get("AA_WIFI_SSID", "SDT Multimedia")
PASSWORD = os.environ.get("AA_WIFI_PASSWORD", "12345678")
CHANNEL = int(os.environ.get("AA_WIFI_CHANNEL", "149"))
AP_IP = os.environ.get("AA_WIFI_AP_IP", "10.10.0.1")
AA_PORT = int(os.environ.get("AA_WIRELESS_PORT", "5277"))
BT_ADAPTER = os.environ.get("AA_BT_ADAPTER", "hci0")
BT_NAME = os.environ.get("AA_BT_NAME", "SDT Multimedia")
AP_PROFILE = os.environ.get("AA_WIFI_PROFILE", "SDT-Android-Auto-Wireless")


def emit(state: str, message: str) -> None:
    print(f"STATUS\t{state}\t{message}", flush=True)


def log(message: str) -> None:
    print(message, flush=True)


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(args), check=check, capture_output=True, text=True, timeout=30
    )


def find_wifi_interface() -> str:
    configured = os.environ.get("AA_WIFI_INTERFACE", "").strip()
    if configured:
        return configured
    wireless_root = Path("/sys/class/net")
    for interface in sorted(wireless_root.iterdir()):
        if (interface / "wireless").exists():
            return interface.name
    raise RuntimeError("Adaptor Wi-Fi tidak ditemukan")


class AccessPoint:
    def __init__(self, interface: str) -> None:
        self.interface = interface
        self.previous_connection = ""
        self.started = False

    def start(self) -> None:
        current = run(
            "nmcli", "-g", "GENERAL.CONNECTION", "device", "show", self.interface
        ).stdout.strip()
        if current and current not in ("--", AP_PROFILE):
            self.previous_connection = current

        profiles = run("nmcli", "-t", "-f", "NAME", "connection", "show").stdout
        if AP_PROFILE not in profiles.splitlines():
            run(
                "nmcli", "connection", "add", "type", "wifi", "ifname",
                self.interface, "con-name", AP_PROFILE, "ssid", SSID,
            )

        band = "a" if CHANNEL >= 36 else "bg"
        run(
            "nmcli", "connection", "modify", AP_PROFILE,
            "connection.autoconnect", "no",
            "802-11-wireless.mode", "ap",
            "802-11-wireless.band", band,
            "802-11-wireless.channel", str(CHANNEL),
            "802-11-wireless.hidden", "no",
            "wifi-sec.key-mgmt", "wpa-psk",
            "wifi-sec.psk", PASSWORD,
            "ipv4.method", "shared",
            "ipv4.addresses", f"{AP_IP}/24",
            "ipv6.method", "disabled",
        )
        result = run(
            "nmcli", "--wait", "25", "connection", "up", AP_PROFILE,
            "ifname", self.interface, check=False,
        )
        if result.returncode != 0:
            reason = result.stderr.strip() or result.stdout.strip() or "unknown error"
            raise RuntimeError(f"Hotspot gagal aktif: {reason}")
        self.started = True
        emit("discovering", f"Hotspot {SSID} aktif; menunggu pairing Bluetooth")

    def stop(self) -> None:
        if self.started:
            run("nmcli", "connection", "down", AP_PROFILE, check=False)
            self.started = False
        if self.previous_connection:
            run(
                "nmcli", "--wait", "20", "connection", "up",
                self.previous_connection, "ifname", self.interface, check=False,
            )

    @property
    def bssid(self) -> str:
        return (Path("/sys/class/net") / self.interface / "address").read_text().strip().upper()


def encode_varint(value: int) -> bytes:
    output = bytearray()
    while value > 0x7F:
        output.append((value & 0x7F) | 0x80)
        value >>= 7
    output.append(value & 0x7F)
    return bytes(output)


def pb_string(field: int, value: str) -> bytes:
    data = value.encode("utf-8")
    return encode_varint((field << 3) | 2) + encode_varint(len(data)) + data


def pb_varint(field: int, value: int) -> bytes:
    return encode_varint(field << 3) + encode_varint(value)


def frame(message_id: int, payload: bytes) -> bytes:
    return struct.pack(">HH", len(payload), message_id) + payload


def channel_frequency(channel: int) -> int:
    if channel <= 13:
        return 2412 + (channel - 1) * 5
    if channel == 14:
        return 2484
    if 36 <= channel <= 177:
        return 5180 + (channel - 36) * 5
    return 5745


def version_request() -> bytes:
    frequency = encode_varint(channel_frequency(CHANNEL))
    packed_channels = bytes([0x22]) + encode_varint(len(frequency)) + frequency
    return frame(4, pb_varint(1, 6) + pb_varint(2, 0) + packed_channels)


def start_request() -> bytes:
    return frame(1, pb_string(1, AP_IP) + pb_varint(2, AA_PORT))


def info_response(bssid: str) -> bytes:
    payload = (
        pb_string(1, SSID)
        + pb_string(2, PASSWORD)
        + pb_string(3, bssid)
        + pb_varint(4, 8)  # WPA2_PERSONAL
        + pb_varint(5, 0)  # STATIC access point
    )
    return frame(3, payload)


def recv_exactly(connection: socket.socket, length: int) -> bytes:
    output = bytearray()
    while len(output) < length:
        chunk = connection.recv(length - len(output))
        if not chunk:
            raise ConnectionError("RFCOMM ditutup saat membaca WPP")
        output.extend(chunk)
    return bytes(output)


def recv_frame(connection: socket.socket) -> tuple[int, bytes]:
    length, message_id = struct.unpack(">HH", recv_exactly(connection, 4))
    return message_id, recv_exactly(connection, length) if length else b""


def run_wpp(connection: socket.socket, phone_mac: str, bssid: str) -> None:
    emit("connecting", f"Bluetooth {phone_mac} terhubung; negosiasi Wi-Fi")
    try:
        connection.settimeout(15)
        connection.sendall(version_request())
        pending: tuple[int, bytes] | None = None
        try:
            message_id, payload = recv_frame(connection)
            if message_id != 5:
                pending = (message_id, payload)
        except socket.timeout:
            pass

        connection.sendall(start_request())
        connection.settimeout(45)
        while True:
            if pending:
                message_id, payload = pending
                pending = None
            else:
                message_id, payload = recv_frame(connection)

            if message_id == 2:  # WifiInfoRequest
                connection.sendall(info_response(bssid))
            elif message_id == 6:  # WifiConnectionStatus
                status = payload[1] if len(payload) >= 2 else 0
                if status == 0:
                    emit("connecting", "Ponsel masuk hotspot; membuka sesi Android Auto")
                else:
                    emit("error", f"Ponsel gagal masuk hotspot (status {status})")
            elif message_id == 8:  # ping
                connection.sendall(frame(9, payload))
            elif message_id not in (5, 7):
                log(f"WPP message tidak dikenal: id={message_id}, length={len(payload)}")
    except socket.timeout:
        emit("discovering", "WPP timeout; menunggu ponsel mencoba kembali")
    except (ConnectionError, OSError) as error:
        emit("discovering", f"Bluetooth terputus ({error}); menunggu koneksi kembali")
    finally:
        connection.close()


AA_SDP_RECORD = """<?xml version="1.0" encoding="UTF-8" ?>
<record>
  <attribute id="0x0001"><sequence>
    <uuid value="4de17a00-52cb-11e6-bdf4-0800200c9a66" />
  </sequence></attribute>
  <attribute id="0x0004"><sequence>
    <sequence><uuid value="0x0100" /></sequence>
    <sequence><uuid value="0x0003" /><uint8 value="0x08" /></sequence>
  </sequence></attribute>
  <attribute id="0x0005"><sequence><uuid value="0x1002" /></sequence></attribute>
  <attribute id="0x0100"><text value="Android Auto Wireless" /></attribute>
</record>"""


class PairingAgent(dbus.service.Object):
    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self) -> None:
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, _device: str, _uuid: str) -> None:
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, _device: str) -> str:
        return "0000"

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, _device: str) -> dbus.UInt32:
        return dbus.UInt32(0)

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, _device: str, _passkey: int, _entered: int) -> None:
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, _device: str, _pin: str) -> None:
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, _device: str, _passkey: int) -> None:
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, _device: str) -> None:
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self) -> None:
        pass


class AndroidAutoProfile(dbus.service.Object):
    def __init__(self, bus: dbus.SystemBus, path: str, bssid: str) -> None:
        super().__init__(bus, path)
        self.bssid = bssid

    @dbus.service.method(PROFILE_IFACE, in_signature="oha{sv}")
    def NewConnection(self, device_path, fd, _properties) -> None:
        raw_fd = fd.take() if hasattr(fd, "take") else int(fd)
        path_text = str(device_path)
        phone_mac = path_text.split("/dev_")[-1].replace("_", ":")
        connection = socket.socket(fileno=raw_fd)
        threading.Thread(
            target=run_wpp,
            args=(connection, phone_mac, self.bssid),
            daemon=True,
            name="android-auto-wpp",
        ).start()

    @dbus.service.method(PROFILE_IFACE, in_signature="o")
    def RequestDisconnection(self, _device_path) -> None:
        pass

    @dbus.service.method(PROFILE_IFACE)
    def Release(self) -> None:
        pass


class Advertisement(dbus.service.Object):
    @dbus.service.method(
        "org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}"
    )
    def GetAll(self, _interface):
        return {
            "Type": dbus.String("peripheral"),
            "ServiceUUIDs": dbus.Array([AA_UUID], signature="s"),
            "LocalName": dbus.String(BT_NAME),
        }

    @dbus.service.method(
        "org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v"
    )
    def Get(self, interface, property_name):
        return self.GetAll(interface)[property_name]

    @dbus.service.method(LE_AD_IFACE, in_signature="", out_signature="")
    def Release(self) -> None:
        pass


class BluetoothBootstrap:
    def __init__(self, bus: dbus.SystemBus, bssid: str) -> None:
        self.bus = bus
        self.profile_manager = dbus.Interface(
            bus.get_object(BLUEZ, "/org/bluez"), "org.bluez.ProfileManager1"
        )
        self.agent_manager = dbus.Interface(
            bus.get_object(BLUEZ, "/org/bluez"), "org.bluez.AgentManager1"
        )
        self.profile = AndroidAutoProfile(bus, AA_PROFILE_PATH, bssid)
        self.agent = PairingAgent(bus, AA_AGENT_PATH)
        self.advertisement = Advertisement(bus, AA_AD_PATH)
        self.ad_manager = None
        self.adapter_properties = dbus.Interface(
            bus.get_object(BLUEZ, f"/org/bluez/{BT_ADAPTER}"),
            "org.freedesktop.DBus.Properties",
        )

    def start(self) -> None:
        run("rfkill", "unblock", "bluetooth", check=False)

        def step(name, callback) -> None:
            log(f"BlueZ: {name}")
            try:
                callback()
            except dbus.DBusException as error:
                if error.get_dbus_name() == "org.bluez.Error.Busy":
                    raise RuntimeError(
                        "Bluetooth BlueZ sedang macet (org.bluez.Error.Busy). "
                        "Jalankan 'sudo systemctl restart bluetooth.service', "
                        "lalu tekan Android Auto Wireless kembali"
                    ) from error
                raise RuntimeError(
                    f"Bluetooth gagal pada {name}: {error.get_dbus_name()}"
                    f" {error.get_dbus_message()}"
                ) from error

        def set_if_different(property_name, value) -> None:
            current = self.adapter_properties.Get(
                "org.bluez.Adapter1", property_name
            )
            if current == value:
                log(f"BlueZ: {property_name} sudah sesuai")
                return
            self.adapter_properties.Set(
                "org.bluez.Adapter1", property_name, value
            )

        # Remove registrations left by an interrupted helper. BlueZ normally
        # cleans these when the D-Bus owner exits, but explicit cleanup makes
        # rapid retry deterministic.
        try:
            self.profile_manager.UnregisterProfile(AA_PROFILE_PATH)
        except dbus.DBusException:
            pass
        try:
            self.agent_manager.UnregisterAgent(AA_AGENT_PATH)
        except dbus.DBusException:
            pass

        step(
            "mengatur nama adaptor",
            lambda: set_if_different("Alias", BT_NAME),
        )
        step(
            "menyalakan adaptor",
            lambda: set_if_different("Powered", True),
        )
        step(
            "mengatur timeout discoverable",
            lambda: set_if_different("DiscoverableTimeout", dbus.UInt32(0)),
        )
        step(
            "mendaftarkan pairing agent",
            lambda: self.agent_manager.RegisterAgent(
                AA_AGENT_PATH, "KeyboardDisplay"
            ),
        )
        step(
            "mengaktifkan pairing agent",
            lambda: self.agent_manager.RequestDefaultAgent(AA_AGENT_PATH),
        )
        step(
            "mendaftarkan profil Android Auto",
            lambda: self.profile_manager.RegisterProfile(
                AA_PROFILE_PATH,
                AA_UUID,
                {
                    "Name": "Android Auto Wireless",
                    "Role": "server",
                    "Channel": dbus.UInt16(8),
                    "RequireAuthentication": False,
                    "RequireAuthorization": False,
                    "ServiceRecord": AA_SDP_RECORD,
                },
            ),
        )

        pairable_error = None
        for attempt in range(5):
            try:
                set_if_different("Pairable", True)
                pairable_error = None
                break
            except dbus.DBusException as error:
                pairable_error = error
                if error.get_dbus_name() != "org.bluez.Error.Busy":
                    break
                log(f"BlueZ pairable masih busy; retry {attempt + 1}/5")
                time.sleep(1)
        if pairable_error is not None:
            if pairable_error.get_dbus_name() == "org.bluez.Error.Busy":
                raise RuntimeError(
                    "Bluetooth BlueZ macet pada mode Pairable. Jalankan "
                    "'sudo systemctl restart bluetooth.service', lalu tekan "
                    "Android Auto Wireless kembali"
                ) from pairable_error
            raise RuntimeError(
                "Bluetooth gagal pada mengaktifkan pairable: "
                f"{pairable_error.get_dbus_name()} "
                f"{pairable_error.get_dbus_message()}"
            ) from pairable_error

        # Some controllers briefly report Busy immediately after switching
        # the only Wi-Fi interface into AP mode. Give BlueZ a short settling
        # window before treating discoverable as a real failure.
        last_error = None
        for attempt in range(5):
            try:
                set_if_different("Discoverable", True)
                last_error = None
                break
            except dbus.DBusException as error:
                last_error = error
                if error.get_dbus_name() != "org.bluez.Error.Busy":
                    break
                log(f"BlueZ discoverable masih busy; retry {attempt + 1}/5")
                time.sleep(1)
        if last_error is not None:
            raise RuntimeError(
                "Bluetooth gagal pada mengaktifkan discoverable: "
                f"{last_error.get_dbus_name()} {last_error.get_dbus_message()}"
            ) from last_error

        # Advertising is queued only after the adapter's BR/EDR pairing state
        # is final. If queued earlier, BlueZ is waiting for GetAll() from our
        # not-yet-running GLib loop and reports Busy to the Pairable setter.
        objects = dbus.Interface(
            self.bus.get_object(BLUEZ, "/"), "org.freedesktop.DBus.ObjectManager"
        ).GetManagedObjects()
        ad_path = next(
            (
                str(path)
                for path, interfaces in objects.items()
                if "org.bluez.LEAdvertisingManager1" in interfaces
            ),
            None,
        )
        if ad_path:
            self.ad_manager = dbus.Interface(
                self.bus.get_object(BLUEZ, ad_path),
                "org.bluez.LEAdvertisingManager1",
            )
            self.ad_manager.RegisterAdvertisement(
                AA_AD_PATH,
                {},
                reply_handler=lambda: log("BLE Android Auto advertisement aktif"),
                error_handler=lambda error: log(
                    f"BLE advertisement dilewati (SDP tetap aktif): {error}"
                ),
            )
        emit("discovering", f"Bluetooth {BT_NAME} siap dipasangkan")

    def stop(self) -> None:
        # Keep the adapter pairable/discoverable between wireless attempts.
        # On this Jetson controller, toggling both modes off during teardown can
        # leave BlueZ's MGMT_SETTING_BONDABLE operation pending indefinitely;
        # the next attempt then fails with org.bluez.Error.Busy. The Android
        # Auto profile and advertisement are still removed below, so no WPP
        # session is exposed while the helper is stopped.
        if self.ad_manager:
            try:
                self.ad_manager.UnregisterAdvertisement(AA_AD_PATH)
            except dbus.DBusException:
                pass
        try:
            self.profile_manager.UnregisterProfile(AA_PROFILE_PATH)
        except dbus.DBusException:
            pass
        try:
            self.agent_manager.UnregisterAgent(AA_AGENT_PATH)
        except dbus.DBusException:
            pass


def main() -> int:
    interface = find_wifi_interface()
    if len(PASSWORD) < 8:
        raise RuntimeError("Password hotspot minimal 8 karakter")

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    access_point = AccessPoint(interface)
    bluetooth: BluetoothBootstrap | None = None
    loop = GLib.MainLoop()

    def stop(_signum=None, _frame=None) -> None:
        loop.quit()

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    try:
        access_point.start()
        bluetooth = BluetoothBootstrap(dbus.SystemBus(), access_point.bssid)
        bluetooth.start()
        loop.run()
        return 0
    finally:
        emit("disconnected", "Mematikan Android Auto wireless")
        if bluetooth:
            bluetooth.stop()
        access_point.stop()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        emit("error", str(error))
        print(f"wireless helper error: {error}", file=sys.stderr, flush=True)
        raise SystemExit(1)
