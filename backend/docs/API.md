# Backend API Reference

Base URL lokal:

```text
http://127.0.0.1:8000
```

## Health

### `GET /`

Response:

```json
{
  "message": "FaceID backend is running"
}
```

## Camera

### `GET /camera_feed`

Mengembalikan live MJPEG stream untuk browser.

Contoh:

```text
http://127.0.0.1:8000/camera_feed
```

### `GET /capture_face`

Mengambil satu frame JPEG dari kamera terbaru.

### `WS /ws/camera`

WebSocket stream JPEG frame untuk Flutter.

Contoh Flutter:

```dart
LiveCameraWS(url: "ws://127.0.0.1:8000/ws/camera")
```

## Driver Recognition

### `GET /driver_status`

Mengembalikan driver yang sedang dikenali kamera.

Response:

```json
{
  "driver": "Febrian",
  "recognized": true,
  "confidence": 0.42,
  "bbox": [120, 80, 220, 220]
}
```

### `GET /drivers`

Mengembalikan daftar driver dari folder dataset.

Response:

```json
{
  "drivers": ["Febrian", "Nikko"]
}
```

### `DELETE /driver/{name}`

Menghapus dataset driver, menghapus label driver, retrain model LBPH dari dataset yang tersisa, lalu reload recognizer.

Contoh:

```bash
curl -X DELETE http://127.0.0.1:8000/driver/Febrian
```

Response sukses:

```json
{
  "success": true,
  "message": "Driver deleted and recognizer reloaded",
  "driver_name": "Febrian"
}
```

## Enrollment

### `POST /enroll`

Upload satu image dan simpan face crop ke dataset driver.

Form fields:

- `driver_name`: nama driver.
- `image`: file image.

### `POST /enroll_live_burst`

Capture banyak sample langsung dari live camera backend dan retrain LBPH.

Form fields:

- `driver_name`: nama driver.
- `duration_sec`: durasi capture, default 8 detik.
- `target_samples`: target jumlah sample, default 60.

Contoh:

```bash
curl -X POST http://127.0.0.1:8000/enroll_live_burst \
  -F "driver_name=Febrian" \
  -F "duration_sec=8" \
  -F "target_samples=60"
```

Response sukses:

```json
{
  "success": true,
  "message": "Driver enrolled from live burst successfully",
  "driver_name": "Febrian",
  "label_id": 1,
  "saved_count": 60
}
```

## Drowsiness + Mood

### `POST /start_drowsiness`

Mulai monitoring untuk driver tertentu.

Request:

```json
{
  "driver_name": "Febrian"
}
```

Response:

```json
{
  "success": true,
  "message": "Drowsiness monitoring started for Febrian",
  "active": true,
  "driver_name": "Febrian"
}
```

### `POST /stop_drowsiness`

Stop monitoring.

Response:

```json
{
  "success": true,
  "message": "Drowsiness monitoring stopped",
  "active": false
}
```

### `GET /drowsiness_status`

Status realtime drowsiness dan mood.

Response utama:

```json
{
  "active": true,
  "driver_name": "Febrian",
  "recognized_driver": "Febrian",
  "driver_match": true,
  "ear": 0.274,
  "mar": 0.145,
  "mood": "happy",
  "mood_confidence": 0.82,
  "raw_mood": "happy",
  "mood_candidate": "happy",
  "mood_candidate_elapsed": 7.1,
  "mood_required_sec": 7.0,
  "smile_score": 0.82,
  "sadness_score": 0.0,
  "yawn_status": "NO",
  "yawn_total": 0,
  "yawns_in_window": 0,
  "eye_score": 0.0,
  "yawn_score": 0.0,
  "ear_ratio": 0.96,
  "score": 0.0,
  "alert_active": false,
  "calibrating": false,
  "calib_remaining": 0.0,
  "status": "normal",
  "face_position": "frontal"
}
```

Status umum:

- `inactive`: monitoring mati.
- `calibrating`: baseline EAR sedang dikalibrasi.
- `normal`: driver tidak mengantuk.
- `drowsy`: alert kantuk aktif.
- `waiting_driver`: wajah yang dikenali belum cocok dengan target driver.

Mood fields:

- `raw_mood`: hasil frame terbaru.
- `mood`: hasil confirmed setelah stabil.
- `mood_candidate_elapsed`: durasi candidate mood bertahan.
- `mood_required_sec`: durasi yang dibutuhkan untuk confirmed.

## Test Commands

```bash
python backend/test_mood_detection.py --driver Febrian
```

```bash
curl http://127.0.0.1:8000/driver_status
```

```bash
curl http://127.0.0.1:8000/drowsiness_status
```
