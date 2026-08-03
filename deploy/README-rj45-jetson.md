# Jetson RJ45 deployment

The application listens on `0.0.0.0:5050` and expects UTF-8 newline-delimited
JSON from the Raspberry Pi at `192.168.50.1`.

Configure the detected Ethernet interface once (the current Jetson interface is
`enP8p1s0`):

```bash
sudo ./scripts/configure_rj45_jetson.sh enP8p1s0
```

Build on the Jetson itself:

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build linux --release
```

Install graphical-session autostart for the current checkout:

```bash
mkdir -p "$HOME/.config/autostart"
cp deploy/toyota-multimedia.desktop \
  "$HOME/.config/autostart/toyota-multimedia.desktop"
```

If the checkout moves, update `Exec=` in the desktop file. Logs are written to
`$XDG_STATE_HOME/toyota-multimedia/startup.log` (or
`$HOME/.local/state/toyota-multimedia/startup.log`). Do not run the Flutter GUI
as a root system service.

Useful verification commands:

```bash
ip -br address show enP8p1s0
ip route get 192.168.50.1
ip route show default
ss -ltnp | grep ':5050'
ping -c 4 192.168.50.1
```
