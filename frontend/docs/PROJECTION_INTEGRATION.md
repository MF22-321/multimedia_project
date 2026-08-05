# Android Auto Kabel dan Wireless — Tahap 1 & 3

Flutter tetap menjadi satu-satunya HMI. Receiver Android Auto berjalan sebagai
proses lokal di belakang plugin Linux dan hasil videonya ditampilkan memakai
`FlPixelBufferTexture`; tidak ada jendela LIVI kedua.

```text
Galaxy / Android phone
  -> USB AOAP, atau Bluetooth WPP + Wi-Fi AP 10.10.0.1:5277
  -> receiver Node.js + protocol stack LIVI
  -> H.264 Annex-B melalui TCP lokal 127.0.0.1:5281
  -> GStreamer h264parse + Jetson NVDEC/VIC + RGBA appsink
  -> FlPixelBufferTexture
  -> Flutter ProjectionPage

Flutter touch
  -> MethodChannel
  -> C++ IPC
  -> Android Auto input channel
  -> phone
```

## Yang sudah berfungsi

- Deteksi ponsel USB melalui `libudev`.
- Handshake Android Open Accessory Protocol.
- Re-enumerasi USB ke VID/PID Google accessory.
- Negosiasi TLS dan service discovery Android Auto.
- Channel control, video, audio, input, sensor, navigation, dan media status.
- Negosiasi codec H.264.
- Decode frame H.264 `1280x720` memakai NVDEC/VIC Jetson, dengan fallback
  decoder CPU bila plugin hardware tidak tersedia.
- Render frame RGBA sebagai texture di halaman Flutter yang sama.
- Tampilan otomatis menjadi fullscreen ketika receiver native aktif.
- Touch down/move/up dari Flutter dikirim kembali ke ponsel.
- PCM musik `48 kHz stereo`, navigasi `16 kHz mono`, dan suara sistem
  `16 kHz mono` dirutekan ke sink PipeWire/PulseAudio default Jetson.
- Pipeline audio dibuat saat frame PCM pertama diterima agar clock output tidak
  berjalan lebih dahulu selama negosiasi USB. Musik memakai startup jitter
  buffer 120 ms yang dilepas satu kali; `min-threshold-time` otomatis menjadi
  nol setelah siap agar output tidak kembali hidup-mati. Timestamp mengikuti
  waktu kedatangan dan sink tidak memaksakan lompatan clock saat startup.
- Pengiriman IPC tidak menyalin ulang frame H.264 dan texture RGBA memakai
  pertukaran double-buffer untuk mengurangi beban CPU/memori.
- Disconnect dan reset USB kembali ke MTP.
- Recovery sesi pre-RUNNING yang macet.
- Simulator tetap menjadi fallback bila receiver lokal belum dipasang.
- Mode wireless membuat hotspot `SDT Multimedia`, mendaftarkan profil BlueZ
  Android Auto UUID `4de17a00-52cb-11e6-bdf4-0800200c9a66` pada RFCOMM channel
  8, lalu menjalankan pertukaran version/start/info/status WPP.
- Sesi TCP wireless memakai server port `5277`; video, audio, touch, dan
  fullscreen memakai pipeline yang sama dengan jalur USB.
- NetworkManager mengembalikan koneksi Wi-Fi yang sebelumnya aktif setelah
  tombol putuskan ditekan.

Uji fisik pada Jetson tanggal 5 Agustus 2026 berhasil membaca Samsung,
menyelesaikan session setup, memilih H.264, dan mendecode frame pertama pada
resolusi `1280x720`.

## Instalasi satu kali

Jalankan dari root project:

```bash
cd /home/multimedia/development/multimedia_project
./scripts/setup_android_auto_receiver.sh
```

Script memasang runtime Node.js ARM64 lokal ke `.tools/`, memverifikasi
checksum unduhan, memasang modul `usb`/`protobufjs`, lalu membangun receiver.
Folder runtime dan hasil build tidak dimasukkan ke Git.

Jetson ini sudah memiliki rule USB LIVI di `/etc/udev/rules.d/99-LIVI.rules`
untuk Samsung `04e8` dan accessory `18d1:2d00-2d05`.

## Menjalankan seperti biasa

Setelah instalasi satu kali, gunakan startup utama yang sama:

```bash
cd /home/multimedia/development/multimedia_project
./startup.sh
```

Lalu tekan ikon `Android Auto` di home screen atau menu aplikasi. Pilih
`Android Auto · Kabel` atau `Android Auto · Wireless`. Halaman Android Auto dan Apple CarPlay memiliki
nuansa serta kontrol terpisah; halaman Android Auto tidak menampilkan CarPlay,
dan sebaliknya. Plugin C++ menjalankan receiver otomatis; jangan menjalankan
LIVI/Electron secara terpisah.

Untuk diagnosis yang langsung membuka halaman dan memulai Android Auto:

```bash
PROJECTION_AUTOSTART_ANDROID_AUTO=1 ./startup.sh
```

## Urutan status yang normal

```text
Receiver Android Auto kabel siap
Mencari ponsel Android pada USB
Memulai Android Open Accessory 04e8:6860
Ponsel berpindah ke mode accessory
USB accessory siap; negosiasi Android Auto
Android Auto aktif
Android Auto aktif · video 1280x720
```

Untuk wireless, aktifkan Bluetooth dan Wi-Fi ponsel lalu pilih tombol
`Android Auto · Wireless`. Jetson akan berpindah dari jaringan Wi-Fi saat ini
ke hotspot `SDT Multimedia`. Pada ponsel, pasangkan Bluetooth dengan perangkat
bernama `SDT Multimedia` dan setujui dialog Android Auto. Status normal:

```text
Menyiapkan hotspot dan Bluetooth Android Auto wireless
Hotspot SDT Multimedia aktif; menunggu pairing Bluetooth
Bluetooth SDT Multimedia siap dipasangkan
Bluetooth <MAC ponsel> terhubung; negosiasi Wi-Fi
Ponsel masuk hotspot; membuka sesi Android Auto
Android Auto wireless aktif
```

Jetson ini hanya mempunyai satu adaptor Wi-Fi `wlP1p1s0`. Karena itu internet
melalui `K1-TLC` berhenti selama proyeksi wireless dan dipulihkan saat sesi
diputus. Gunakan adaptor Wi-Fi USB kedua jika hotspot dan internet harus aktif
bersamaan.

Konfigurasi wireless dapat ditimpa melalui environment variable:

```bash
AA_WIFI_INTERFACE=wlP1p1s0 \
AA_WIFI_SSID='SDT Multimedia' \
AA_WIFI_PASSWORD='12345678' \
AA_WIFI_CHANNEL=149 \
./startup.sh
```

`lsusb` sebelum koneksi biasanya memperlihatkan Samsung MTP:

```text
04e8:6860 Samsung ... (MTP)
```

Saat Android Auto aktif, perangkat berubah menjadi:

```text
18d1:2d00 Google Inc. Android Open Accessory device
```

Saat Disconnect ditekan, receiver melepas interface dan mereset ponsel kembali
ke MTP.

## Diagnosis

Periksa perangkat:

```bash
lsusb | grep -Ei '04e8|18d1:2d'
```

Periksa wireless:

```bash
nmcli device status
nmcli connection show --active
bluetoothctl show
ss -ltn | grep 5277
```

Periksa output audio aktif:

```bash
pactl get-default-sink
pactl get-sink-volume @DEFAULT_SINK@
pactl get-sink-mute @DEFAULT_SINK@
```

Receiver mengikuti sink PipeWire/PulseAudio default. Untuk memilih pipeline
sink lain saat diagnosis, gunakan `AA_AUDIO_SINK`, misalnya:

```bash
AA_AUDIO_SINK='pulsesink device=alsa_output.platform-sound.analog-stereo sync=true' ./startup.sh
```

Log `Android Auto render performance: ... fps` dicetak setiap lima detik.
Pada Jetson, decoder yang diharapkan adalah `Android Auto video decoder:
Jetson NVDEC/VIC`. Fallback dapat diuji dengan
`AA_VIDEO_DECODER=software ./startup.sh`.

Jetson saat ini sudah memakai `MAXN_SUPER`. Untuk demo dengan clock maksimum,
jalankan secara sadar (daya dan suhu akan meningkat):

```bash
./scripts/jetson_max_performance.sh
```

Build ulang receiver setelah mengubah TypeScript:

```bash
./scripts/build_android_auto_receiver.sh
```

Uji receiver tanpa Flutter selama 30 detik:

```bash
./scripts/run_android_auto_receiver.sh
```

Pada terminal kedua:

```bash
.tools/node-v24.18.0-linux-arm64/bin/node \
  frontend/projection_receiver/scripts/probe.mjs
```

Jika proses dihentikan paksa ketika ponsel masih `18d1:2d00` dan sesi baru
gagal pada TLS, kembalikan ponsel ke MTP:

```bash
usbreset 18d1:2d00
```

## Verifikasi kode

```bash
./scripts/build_android_auto_receiver.sh
cd frontend
/home/multimedia/flutter/flutter/bin/flutter analyze --no-pub
/home/multimedia/flutter/flutter/bin/flutter test --no-pub
/home/multimedia/flutter/flutter/bin/flutter build linux --release
```

Sumber `projection_receiver/src/stack`, `src/protos`, serta referensi helper
wireless diambil dari LIVI commit
`b7435e8db1fcc9b5280c45fb71d020d943577ef7`. Salinan lisensinya berada di
`projection_receiver/LICENSE-LIVI-GPL-3.0`.
