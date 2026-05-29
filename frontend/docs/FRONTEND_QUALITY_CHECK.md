# Frontend Quality Check

Last reviewed: 2026-05-28

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
