# In-Car Smart Fragrance Android

Aplikasi Flutter Android standalone untuk mengontrol prototype Smart Fragrance
melalui MQTT.

## Fitur

- UI light, responsif, dan mobile-first.
- Main power dan automatic fragrance cycle.
- Kontrol aktif/nonaktif untuk Cartridge 1 dan Cartridge 2.
- Pengaturan intensitas level 1–3 dengan tombol minus/plus.
- Sinkronisasi state dua arah dengan ESP32 dan multimedia melalui MQTT.
- Status koneksi broker, ESP32, pengiriman, dan konfirmasi state.
- Launcher icon `TOYOTA — In-Car Smart Fragrance V1`.

## Menjalankan aplikasi

```powershell
cd fragrance_control_android
flutter pub get
flutter run
```

Build APK release:

```powershell
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## MQTT

Broker:

```text
broker.hivemq.com:1883
```

Topic:

```text
humidifier/control
humidifier/state
```

Contoh payload:

```json
{
  "selectedCartridge": 1,
  "mainPower": true,
  "autoMode": false,
  "autoInterval": "10s",
  "motor1": {
    "enabled": true,
    "speedLevel": 2
  },
  "motor2": {
    "enabled": false,
    "speedLevel": 1
  }
}
```

Perubahan kontrol dikirim otomatis. ESP32 perlu memublikasikan state terbaru
ke `humidifier/state` agar aplikasi menerima konfirmasi dan seluruh UI tetap
sinkron.

## Pengujian

```powershell
flutter analyze
flutter test
```

Pengujian responsif mencakup beberapa ukuran HP serta simulasi font scaling
besar seperti pada perangkat Samsung.

## Catatan font

Repository publik ini tidak menyertakan Toyota Type atau font proprietary
lainnya. Aplikasi menggunakan font sistem Android.
