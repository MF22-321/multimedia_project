# Frontend Development Guide

## Run Locally

Pastikan backend berjalan:

```bash
cd /home/febrian/development/multimedia_project
conda activate drwosy
python -m uvicorn backend.fastAPI.main:app --host 127.0.0.1 --port 8000
```

Jalankan Flutter:

```bash
cd /home/febrian/development/multimedia_project/frontend
flutter pub get
flutter run -d linux
```

## Useful Checks

```bash
flutter analyze
dart format lib
```

Jika command `flutter` atau `dart` tidak tersedia, jalankan dari environment yang sudah punya Flutter SDK di PATH.

## Clean-Code Checklist

Sebelum menambah fitur:

- Taruh UI feature di `lib/features/<feature>/presentation`.
- Taruh HTTP/WebSocket/device integration di `lib/core/services`.
- Taruh route name di `AppRoutes`.
- Taruh base URL backend di `BackendConfig`.
- Jangan hard-code `http://127.0.0.1:8000` di UI.
- Jangan hard-code route seperti `"/home"` di widget.
- Jangan hitung vision/drowsiness/mood di Flutter; ambil dari backend.
- Simpan state global ringan di `core/navigation`.
- Gunakan provider jika state perlu notify banyak widget.
- Gunakan `AppLogger` untuk debug log; jangan pakai `print`.
- Gunakan `withValues(alpha: ...)` untuk opacity warna baru.

## Backend Connection Test

```bash
curl http://127.0.0.1:8000/
curl http://127.0.0.1:8000/driver_status
curl http://127.0.0.1:8000/drowsiness_status
```

## Drowsiness Switch Test

1. Login sebagai driver.
2. Buka Settings.
3. Matikan `Drowsiness Alert`.
4. Cek:

```bash
curl http://127.0.0.1:8000/drowsiness_status
```

Expected:

```json
{
  "active": false,
  "status": "inactive"
}
```

5. Nyalakan lagi switch.
6. Expected:

```json
{
  "active": true,
  "driver_name": "<driver aktif>"
}
```

## Mood Suggestion Test

1. Pastikan backend mengenali driver:

```text
driver_match=true
```

2. Tahan ekspresi happy/sad sampai `mood` confirmed.
3. Flutter akan membuka dialog rekomendasi musik.

Debug log di `HomePage`:

```text
STATUS: normal | mood=happy | raw=happy | match=true
```

## Known Notes

- `features/face_recognition` berisi beberapa screen debug/legacy yang tidak menjadi flow utama di `main.dart`.
- Flow utama driver selection ada di `features/auth`.
- `HomePage` masih menjadi orchestration utama dan bisa dipecah lagi nanti menjadi controller/service khusus.
