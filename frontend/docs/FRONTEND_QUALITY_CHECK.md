# Frontend Quality Check

Last reviewed: 2026-08-06

## Hasil Eksekusi 6 Agustus 2026

- `flutter analyze`: **lulus, 0 issue**.
- `flutter test --no-pub`: **94 test lulus, 0 gagal**.
- Test lama bawaan template counter diganti dengan test fitur aplikasi.
- Test otomatis tidak menghubungi backend produksi, broker MQTT, atau Pothole API.

Jalankan ulang dari folder `frontend`:

```bash
/home/multimedia/flutter/flutter/bin/flutter test --no-pub
/home/multimedia/flutter/flutter/bin/flutter analyze
```

## Skenario Automated

| ID | Fitur | Skenario | Hasil |
|---|---|---|---|
| FE-001 | Face Recognition | URL WebSocket default | Menggunakan backend config dan `/ws/camera` |
| FE-002 | Face Recognition | Parameter width/fps/quality opsional | Query string terbentuk benar |
| FE-003 | Maps | Konfigurasi tile OpenStreetMap | HTTPS, User-Agent, zoom maksimum 19, atribusi tersedia |
| FE-004 | Maps | GeoJSON route OSRM valid | Koordinat lon/lat dikonversi ke `LatLng` |
| FE-005 | Maps | Response OSRM tanpa geometry | Menghasilkan exception terkontrol |
| FE-006 | Pothole | Parsing serial GPS lengkap | GPS, heading, dan accelerometer terbaca |
| FE-007 | Pothole | Prefix serial invalid | Ditolak dengan `FormatException` |
| FE-008 | Pothole | Kategori dari backend | Mengoverride heuristic lokal |
| FE-009 | Pothole | Threshold pothole/bumper/normal | Klasifikasi sesuai konfigurasi terbaru |
| FE-010 | Pothole | Hazard di depan/belakang kendaraan | Hanya hazard di depan yang dipilih |
| FE-011 | Pothole | Sudut melintasi 0/360 derajat | Selisih sudut dihitung benar |
| FE-012 | Pothole API | Endpoint publik tanpa token | Data tetap dapat dimuat tanpa header Authorization |
| FE-013 | Pothole API | Payload dan koordinat valid/invalid | Data valid diparsing, titik nol dibuang |
| FE-014 | User | Casing nama driver | Nama asli backend dipertahankan |
| FE-015 | User | Preference lama/minimal | Default aman dan bahasa fallback ke Indonesia |
| FE-016 | Theme | Custom theme save/load | Nilai warna dapat dipulihkan |
| FE-017 | Smart Fragrance | Shortcut coffee | Hanya motor coffee aktif |
| FE-018 | Smart Fragrance | Shortcut kedua cartridge | Kedua motor aktif |
| FE-019 | Smart Fragrance | Cartridge invalid | Menghasilkan payload power-off |
| FE-020 | Smart Fragrance | Interval broker invalid | Fallback aman ke 10 detik |
| FE-021 | Pothole serial | Format firmware lama tanpa kategori | Tetap terbaca sebagai `normal` |
| FE-022 | Pothole serial | Format baru dengan kategori/severity | Nilai eksplisit dari ESP32 terbaca |
| FE-023 | ESP32 status | Wi-Fi/GPS offline tetapi USB aktif | Heading/IMU dan status tetap diterima |
| FE-024 | Face enrollment | Poll status fase dan sampel | Arahan dan jumlah sampel terbaca |
| FE-025 | Adaptive Face ID | Check, approve, dan reject kandidat | Method dan endpoint sesuai kontrak |
| FE-026 | Face ID error | Backend quality endpoint gagal | Error diteruskan, tidak dianggap sukses |
| FE-027 | Vehicle 3D | Inisialisasi direct GPU view dan texture fallback | Metadata renderer serta status tersedia terbaca |
| FE-028 | Vehicle 3D | Bounds, visibility, drag, zoom, active, dan reset | Kontrak method channel terkirim benar |
| FE-029 | Vehicle 3D | Native renderer gagal | UI tetap aman memakai fallback PNG |

## Skenario Integrasi Manual

| ID | Fitur | Langkah | Expected |
|---|---|---|---|
| FE-101 | Face Recognition | Backend dan kamera aktif, buka pemilihan driver | Preview tampil dan driver valid login otomatis |
| FE-102 | Face Recognition | Backend mengirim driver stale/tidak terdaftar | Login otomatis diabaikan |
| FE-103 | Maps | Buka map card dan detail dengan internet | Tile tampil, atribusi OSM terlihat dan dapat dibuka |
| FE-104 | Maps | Cari tujuan lalu mulai route | Polyline route OSRM tampil |
| FE-105 | Maps | Zoom hingga maksimum | Berhenti di zoom 19 tanpa tile kosong |
| FE-106 | Pothole | Kirim dua impact sample ESP32 valid | Marker sesuai kategori muncul setelah filter |
| FE-107 | Pothole | Dekati lalu lewati hazard sesuai heading | Satu overlay bertahan dan hilang setelah kondisi aman 2 detik |
| FE-108 | Pothole API | Jalankan dengan token aktif | Marker backend termuat tanpa error authorization |
| FE-109 | Smart Fragrance | Broker dan device aktif, pilih coffee/lavender/both | State motor di device dan UI konsisten |
| FE-110 | Smart Fragrance | Ubah speed dan auto interval | Payload dan state feedback sesuai pilihan |
| FE-111 | User | Pilih driver, restart aplikasi | Preference driver yang sama termuat |
| FE-112 | Theme | Preview lalu back tanpa save | Tema global tidak berubah |
| FE-113 | Theme | Save custom theme lalu masuk Home | Warna/background tersimpan dan diterapkan |
| FE-114 | Vehicle 3D | Buka Home dan halaman detail kendaraan | Direct OpenGL tampil transparan tanpa kotak atau dot hitam |
| FE-115 | Vehicle 3D | Drag dan pinch melalui sudut depan/samping/belakang | Sudut/zoom berubah tanpa panel tembus atau retak segitiga |
| FE-117 | Vehicle 3D | Stress drag delapan detik lalu reset | Z-buffer stabil, tepi MSAA halus, dan reset berhasil |
| FE-116 | Vehicle 3D | Jalankan bersama musik dan Android Auto | UI responsif dan audio tidak terganggu |

Perilaku overlay hazard terbaru:

- Hanya satu overlay yang dapat aktif; telemetry berikutnya memperbarui overlay
  yang sama dan tidak membuka popup baru.
- Overlay tidak memiliki timeout tutup paksa selama pothole/bumper masih berada
  di depan kendaraan.
- Overlay ditutup setelah tidak ada hazard di depan selama 2 detik berturut-turut.
- Hilangnya satu frame GPS tidak langsung menutup overlay, sehingga tampilan
  tidak berkedip.

Endpoint saat ini dapat dibaca tanpa token. Untuk deployment yang memakai
autentikasi, token opsional dapat diberikan saat runtime:

```bash
flutter run -d linux --dart-define=POTHOLE_API_TOKEN=<token-aktif>
```

Token yang sebelumnya tertanam di source kedaluwarsa pada 16 April 2026 dan
telah dihapus. Konfigurasi OpenStreetMap mengikuti URL, identifikasi client,
atribusi, dan zoom tile standar yang didokumentasikan oleh OSM.

Dokumen ini merangkum hasil pengecekan folder `frontend` dari sisi arsitektur, performa UI, navigasi, dan flow live theme.

## Status Singkat

- Struktur folder sudah cukup konsisten: `core` untuk state/service/theme, `features` untuk UI per fitur.
- Flow utama sudah jelas: boot, warning, odd/even, driver select, home, personalize.
- Custom theme sudah memakai pola draft preview. Tema global tidak berubah permanen sampai user menekan `Save Settings` atau `Save Driver`.
- Popup drowsiness dan mood sudah punya guard agar tidak menumpuk.
- Map dan pothole memakai provider, polling, dan dedupe sehingga data backend dan live telemetry tidak langsung membuat marker dobel terlalu banyak.

Catatan tooling: environment shell saat review belum punya command `flutter` dan `dart` di `PATH`, jadi `flutter analyze` dan `dart format` perlu dijalankan dari terminal yang Flutter SDK-nya aktif.

## Arsitektur

### Core Layer

Lokasi utama:

```text
lib/core/
```

Isi dan tanggung jawab:

- `model`: bentuk data seperti driver preference, GPS, pothole.
- `navigation`: state global ringan berbasis `ValueNotifier`.
- `provider`: state reaktif yang perlu dipakai banyak widget.
- `services`: komunikasi backend, serial ESP32, Hive, MQTT, Spotify.
- `themes`: definisi tema, animated background, dan helper warna.
- `localization`: string Bahasa Indonesia dan English.

Rule yang sudah tepat:

- Backend call tidak dicampur langsung ke banyak widget kecil.
- Route utama memakai `AppRoutes`.
- Driver preference disimpan lewat `DriverHiveService`.
- Theme global berada di `CarThemes.currentTheme` dan `CarThemes.customTheme`.

### Feature Layer

Lokasi utama:

```text
lib/features/
```

Struktur sekarang masih dominan `presentation/page` dan `presentation/widget`. Ini masih aman untuk prototype head unit, tetapi file besar seperti `music_page.dart`, `map_detail_page.dart`, dan `custom_theme_page.dart` sebaiknya dipecah bertahap jika fitur bertambah.

Rekomendasi clean architecture berikutnya:

- Pindahkan orchestration berat dari page besar ke controller kecil atau provider per fitur.
- Untuk fitur yang makin kompleks, pakai pola `data`, `domain`, `presentation`.
- Hindari service melakukan navigasi. Service cukup return data/status.

## State Dan Commit Setting

Single source of truth utama:

```text
DriverSession.currentDriver
AppNavigation.currentIndex
AppLanguageControl.languageCode
DrowsinessControl.enabled
CarThemes.currentTheme
CarThemes.customTheme
```

Flow preference driver:

```text
driver original name -> DriverSession
lowercase key        -> Hive preference
displayName          -> nama tampil di UI
```

Flow custom theme:

```text
CustomThemePage
-> return CarThemeData
-> Personalize/AddDriver simpan sebagai _draftCustomTheme
-> preview lokal berubah
-> Save Settings/Save Driver
-> Hive save
-> CarThemes.currentTheme dan customTheme baru di-commit
```

Dengan pola ini, saat user memilih tema di `Multimedia Theme Settings` lalu menekan back tanpa save, Home tetap memakai setting lama. Preview di personalize/add driver boleh berubah lokal, tetapi bukan global app state.

## Navigasi

Flow utama:

```text
BootPage
-> WarningPage
-> OddEvenPage
-> DriverSelectPage
-> HomePage
```

Subpage penting:

```text
HomePage/MenuContent -> PersonalizePage
PersonalizePage      -> CustomThemePage
DriverSelectPage     -> AddDriverPage
```

Catatan UI:

- Tombol back di personalize dan add driver sudah dibuat sebagai area tap satu baris, bukan hanya teks.
- Save pada personalize kembali ke page sebelumnya setelah preference tersimpan.
- Save pada add driver masuk ke Home setelah driver aktif dan preference tersimpan.

## Performa UI

Hal yang sudah baik:

- Global theme tidak diubah saat preview custom theme, sehingga Home tidak rebuild saat user cuma mencoba-coba warna.
- Drowsiness polling tidak memanggil `setState` setiap 800 ms di Home; UI hanya bereaksi saat perlu popup.
- `PotholeProvider` memakai subscriber count untuk start/stop polling realtime.
- Pothole backend dan live telemetry didedupe berdasarkan kategori dan jarak.
- Background image custom hanya aktif jika user memilih gambar. Gradient/preset akan clear image agar tidak saling nabrak.

Area yang perlu diawasi:

- `map_detail_page.dart` hampir 2000 baris dan memegang banyak state UI. Jika ada lag di map detail, pecah menjadi widget/controller untuk route, hazard list, toolbar, dan overlay.
- `music_page.dart` lebih dari 1300 baris. Jika search/player/mood makin kompleks, pisahkan menjadi panel kecil.
- Animated background seperti futuristic/retro/playful sebaiknya hanya aktif di page yang sedang terlihat.
- Hindari menambah polling baru di widget kecil. Polling idealnya berada di provider atau controller dengan dispose jelas.

## Popup Drowsiness Dan Mood

Kontrak popup:

- Drowsiness punya prioritas saat status `drowsy`.
- Mood suggestion hanya muncul saat mood `happy` atau `sad`, driver match, dan cooldown terpenuhi.
- `_activePopup` memastikan hanya satu popup aktif.
- Jika drowsy muncul saat mood popup terbuka, mood popup ditutup dulu lalu drowsy tampil.
- Tombol utama memakai accent yang tetap terlihat, termasuk theme `comfort`.

## Map Dan Pothole

Kontrak data:

- `GPSProvider` membaca serial ESP32.
- `PotholeProvider` membaca backend dan live telemetry.
- `MapCard` dan `MapDetailPage` sebaiknya hanya menampilkan state dari provider.
- Jika GPS belum fix, map tetap bisa menampilkan hazard backend, tetapi posisi realtime kendaraan belum muncul.
- Marker kategori harus memakai field `category`, bukan hard-code pothole.

Checklist manual:

- Jalankan dengan GPS belum fix, pastikan UI tidak blank/crash.
- Kirim sample `category=pothole`, marker/list harus tampil pothole.
- Kirim sample `category=bumper`, marker/list harus tampil bumper.
- Setelah ESP32 mendapat satelit valid, posisi realtime kendaraan muncul dan update.

## Checklist Sebelum Demo

Jalankan dari environment Flutter:

```bash
cd /home/febrian/development/multimedia_project/frontend
flutter analyze
dart format lib
flutter run -d linux
```

Manual QA:

- Login guest: tidak ada tombol delete account.
- Login driver: personalize menampilkan delete account.
- Delete account: face recognition harus match driver aktif sebelum delete.
- Pilih theme di personalize lalu back tanpa save: Home tetap memakai theme lama.
- Pilih theme lalu `Save Settings`: Home dan personalize memakai theme baru.
- Custom theme gambar: preview image tampil, gradient tidak menabrak image.
- Custom theme preset/gradient: image sebelumnya hilang.
- Drowsy popup muncul satu saja.
- Mood popup muncul satu saja dan tidak menimpa drowsy popup.
- Navigasi tab Home tetap halus saat theme berubah.

## Temuan Review Ini

Perbaikan kecil yang dilakukan:

- `PersonalizePage` dan `AddDriverPage` sekarang membaca preference lama memakai lowercase key yang sama dengan format penyimpanan Hive. Ini menjaga language/custom theme lama agar tidak hilang ketika display name punya huruf besar.

Residual risk:

- Belum bisa menjalankan analyzer karena Flutter SDK tidak tersedia di shell review ini.
- Beberapa file UI masih besar. Aman untuk fitur sekarang, tetapi perlu dipecah saat logic bertambah agar maintainability dan performa tetap bagus.
