# Frontend Architecture

Dokumen ini menjelaskan struktur Flutter agar pengembangan fitur berikutnya tetap rapi.

## Goals

- UI dipisah berdasarkan feature.
- Komunikasi backend dan device disimpan di `core/services`.
- State global ringan disimpan di `core/navigation`.
- State reaktif yang kompleks menggunakan `ChangeNotifier` di `core/provider`.
- Route dan backend URL tidak di-hard-code di banyak file.

## Layers

### App Bootstrap

Lokasi:

```text
lib/main.dart
```

Tanggung jawab:

- Inisialisasi Flutter binding.
- Inisialisasi MediaKit, Hive, window manager.
- Register provider global.
- Register route utama via `AppRoutes`.

### Core Layer

Lokasi:

```text
lib/core/
```

Isi:

- `model/`: data model sederhana.
- `navigation/`: route names dan global `ValueNotifier`.
- `provider/`: provider aplikasi seperti music, GPS, pothole, video.
- `services/`: API backend, Spotify, MQTT, serial, local storage.
- `themes/`: theme dan animated background.
- `utils/`: helper umum.

Rule:

- Jangan taruh UI feature di `core`.
- Jangan panggil widget dari service.
- Service harus mengembalikan data, bukan melakukan navigasi.

### Feature Layer

Lokasi:

```text
lib/features/
```

Setiap feature idealnya punya:

```text
feature_name/
└── presentation/
    ├── page/
    └── widget/
```

Feature aktif:

- `auth`: driver selection dan driver enrollment.
- `home`: shell utama head unit.
- `boot`: startup screen.
- `warning`: warning screen.
- `odd_even`: odd/even flow.
- `personalize`: theme customization.
- `smart_fragrance`: fragrance settings.
- `video`: video playback.
- `projection`: one-HMI Android Auto/CarPlay surface, lifecycle controller,
  and Linux native bridge boundary.
- `face_recognition`: sebagian screen debug/legacy untuk FaceID.

## Phone Projection Boundary

`ProjectionPage` owns presentation and normalized touch coordinates. Dart sends
only lifecycle commands, status requests, and input events through a platform
channel. Decoded video never crosses Dart; the Linux receiver adapter registers
an `FlTexture` and returns its texture ID to Flutter.

The project-local C++ bridge lives in `linux/projection_plugin/`. The receiver
in `projection_receiver/` supports both Tahap 1 USB AOAP and Tahap 3 wireless
Bluetooth WPP + Wi-Fi TCP transport. Protocol processing stays outside Dart,
while both transports share the same GStreamer decoder/audio pipeline and
registered Flutter texture. The optional `PROJECTION_SDK_LIBRARY` ABI remains
available for another receiver adapter. See `docs/PROJECTION_INTEGRATION.md`
for setup, runtime flow, and diagnostics.

## Runtime Flow

```text
BootPage
-> WarningPage
-> OddEvenPage
-> DriverSelectPage
-> HomePage
```

`DriverSelectPage` membaca:

```dart
FaceIdApi.getDrivers()
FaceIdApi.getDriverStatus()
```

Jika driver dikenali:

```dart
DriverSession.setDriver(name)
Navigator.pushReplacementNamed(context, AppRoutes.home)
```

`HomePage` kemudian:

```dart
DrowsinessApi.startDrowsiness(driverName: driver)
DrowsinessApi.getDrowsinessStatus()
```

## Route Ownership

Semua route utama didefinisikan di:

```text
lib/core/navigation/app_routes.dart
```

Gunakan:

```dart
Navigator.pushReplacementNamed(context, AppRoutes.home);
```

Hindari:

```dart
Navigator.pushReplacementNamed(context, "/home");
```

## Backend Config

Semua base URL backend ada di:

```text
lib/core/services/backend_config.dart
```

Gunakan `BackendConfig.httpBase` dan `BackendConfig.wsBase`.

## Drowsiness And Mood Boundary

Frontend tidak menghitung EAR/MAR/mood. Frontend hanya:

- Start monitoring.
- Stop monitoring.
- Poll status.
- Menampilkan alert.
- Memberi rekomendasi musik.

Backend tetap menjadi pemilik logic vision.

## Current Technical Debt

Area yang bisa dirapikan bertahap:

- `HomePage` masih memegang beberapa orchestration: theme, drowsiness polling, mood suggestion, dan tab shell.
- Beberapa widget lama di `features/face_recognition` tampak sebagai debug/legacy flow dan tidak masuk route utama.
- Beberapa service masih banyak `debugPrint`/`print`.
- Beberapa UI file besar dapat dipisah menjadi controller/helper kecil.
