# Toyota Multimedia Frontend

Frontend ini adalah aplikasi Flutter untuk head unit multimedia kendaraan. Aplikasi menghubungkan driver recognition, drowsiness detection, mood-based music suggestion, peta, musik, radio, smart fragrance, dan personalisasi driver.

## Quick Start

Jalankan dari folder frontend:

```bash
cd /home/febrian/development/multimedia_project/frontend
flutter pub get
flutter run -d linux
```

Backend harus berjalan di:

```text
http://127.0.0.1:8000
```

Konfigurasi endpoint ada di:

```text
lib/core/services/backend_config.dart
```

## App Flow

```text
BootPage
-> WarningPage
-> OddEvenPage
-> DriverSelectPage
-> HomePage
```

Setelah driver dipilih atau dikenali:

```text
DriverSession.currentDriver
-> HomePage start drowsiness
-> polling /drowsiness_status
-> drowsiness alert dialog
-> mood-based music suggestion
```

## Folder Architecture

```text
lib/
├── main.dart
├── core/
│   ├── model/          # Plain data models
│   ├── navigation/     # Global navigation/session notifiers and route names
│   ├── provider/       # App-level ChangeNotifier providers
│   ├── services/       # API, device, storage, Spotify, MQTT, serial services
│   ├── themes/         # Theme definitions and animated backgrounds
│   └── utils/          # Shared utilities
└── features/
    ├── auth/           # Driver selection and driver enrollment UX
    ├── boot/           # Startup animation
    ├── face_recognition/ # Legacy/debug face recognition screens and widgets
    ├── home/           # Main head-unit shell and widgets
    ├── odd_even/       # Odd/even check intro
    ├── personalize/    # Theme personalization
    ├── smart_fragrance/
    ├── video/
    └── warning/
```

Detail arsitektur ada di [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Clean-Code Boundaries

- `features/*/presentation/` berisi UI dan state lokal halaman.
- `core/services/` berisi komunikasi keluar aplikasi: HTTP, WebSocket, DBus, MQTT, serial, storage.
- `core/navigation/` berisi state global ringan seperti active tab, current driver, dan drowsiness switch.
- `core/provider/` berisi state app yang butuh `ChangeNotifier`.
- Route name harus menggunakan `AppRoutes`, bukan string manual.
- Backend URL harus menggunakan `BackendConfig`, bukan hard-coded di banyak file.
- Debug log aplikasi memakai `AppLogger`, bukan `print`.
- Warna transparan memakai `withValues(alpha: ...)` agar cocok dengan Flutter terbaru.

## Important Runtime State

### Driver Session

```dart
DriverSession.currentDriver
```

Dipakai oleh `HomePage` untuk start monitoring sesuai driver aktif.

### Drowsiness Control

```dart
DrowsinessControl.enabled
```

Dipakai oleh switch Settings untuk stop/start drowsiness backend.

### App Navigation

```dart
AppNavigation.currentIndex
```

Mengatur tab utama:

```text
0 Music
1 Phone
2 Home
3 Menu
4 Settings
```

### Smart Music Suggestion

```dart
SmartMusicSuggestion.suggestedKeyword
```

Diisi dari mood detection untuk memberi rekomendasi musik.

## Backend Integration

Service utama:

```text
lib/core/services/faceid_api.dart
lib/core/services/drowsiness_api.dart
lib/core/services/backend_config.dart
```

Endpoint yang dipakai:

```text
GET  /drivers
GET  /driver_status
POST /enroll_live_burst
POST /start_drowsiness
POST /stop_drowsiness
GET  /drowsiness_status
WS   /ws/camera
```

## Drowsiness + Mood UX

`HomePage` melakukan polling `/drowsiness_status` setiap 800 ms ketika monitoring aktif.

Jika `status == drowsy`, aplikasi menampilkan `DrowsinessAlertPage`.

Jika `mood == happy` atau `mood == sad` dan `driver_match == true`, aplikasi menampilkan rekomendasi musik:

- `happy`: musik bahagia/upbeat.
- `sad`: musik santai/relaxing.

Switch untuk menyalakan/mematikan fitur ada di:

```text
features/home/presentation/widget/settings_content.dart
```

## Development Docs

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/STATE_FLOW.md](docs/STATE_FLOW.md)
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
