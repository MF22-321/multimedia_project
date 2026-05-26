# Frontend State Flow

Dokumen ini menjelaskan state global dan alur data utama.

## Global Notifiers

### `AppNavigation.currentIndex`

Lokasi:

```text
lib/core/navigation/app_navigation.dart
```

Mengatur tab utama `HomePage`.

```text
0 Music
1 Phone
2 Home
3 Menu
4 Settings
```

### `DriverSession.currentDriver`

Lokasi:

```text
lib/core/navigation/driver_session.dart
```

Menyimpan driver aktif. Nilai ini harus memakai nama driver original dari backend, bukan lowercase, karena backend memakai nama ini untuk `driver_match`.

### `DrowsinessControl.enabled`

Lokasi:

```text
lib/core/navigation/drowsiness_control.dart
```

Switch global untuk mengaktifkan atau menonaktifkan drowsiness detection.

Jika `false`:

```text
HomePage -> DrowsinessApi.stopDrowsiness()
```

Jika `true`:

```text
HomePage -> DrowsinessApi.startDrowsiness(driver aktif)
```

### `SmartMusicSuggestion.suggestedKeyword`

Lokasi:

```text
lib/core/navigation/smart_music_navigation.dart
```

Dipakai untuk mengirim keyword musik dari mood detection ke halaman musik.

## Driver Login Flow

```text
DriverSelectPage
-> FaceIdApi.getDriverStatus()
-> recognized driver
-> DriverSession.setDriver(name)
-> AppRoutes.home
```

Manual selection memakai flow yang sama:

```text
tap driver card
-> DriverSession.setDriver(name)
-> AppRoutes.home
```

Guest flow:

```text
GuestButton
-> DriverSession.clear()
-> AppRoutes.home
```

## Drowsiness Flow

```text
HomePage.initState
-> listen DriverSession
-> listen DrowsinessControl
-> start drowsiness if driver != null and enabled == true
```

Polling:

```text
Timer 800 ms
-> DrowsinessApi.getDrowsinessStatus()
-> status drowsy?
-> show DrowsinessAlertPage
```

Disable flow:

```text
Settings switch OFF
-> DrowsinessControl.enabled = false
-> HomePage._stopDrowsiness()
-> POST /stop_drowsiness
```

## Mood Music Flow

```text
GET /drowsiness_status
-> mood == happy/sad
-> driver_match == true
-> set SmartMusicSuggestion keyword
-> show mood suggestion dialog
-> user taps play/open
-> AppNavigation.currentIndex = 0
```

Recommended keywords:

```text
happy -> happy upbeat driving
sad   -> calm relaxing night drive
```

## Driver Preference Flow

Preferences are stored with lowercase keys:

```dart
DriverHiveService.load(driver.toLowerCase())
```

But the active session should keep the original backend name:

```dart
DriverSession.setDriver("Febrian")
```

This distinction matters:

- Lowercase key is for local Hive storage.
- Original name is for backend FaceID matching.
