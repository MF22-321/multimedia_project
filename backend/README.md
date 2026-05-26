# Driver Monitoring Backend

Backend ini menjalankan sistem Driver Monitoring System untuk:

- Face recognition driver menggunakan LBPH + MediaPipe face cropper.
- Drowsiness detection menggunakan EAR, MAR, yawn detection, dan skor kantuk.
- Mood detection ringan untuk `happy`, `sad`, `neutral`, dan `unknown`.
- Live camera stream untuk Flutter lewat HTTP multipart dan WebSocket.
- Enrollment driver serta retraining model LBPH.

Backend diekspos menggunakan FastAPI dan dijalankan dari root repository.

## Quick Start

Aktifkan environment lalu jalankan server:

```bash
cd /home/febrian/development/multimedia_project
conda activate drwosy
python -m uvicorn backend.fastAPI.main:app --host 127.0.0.1 --port 8000
```

Cek health endpoint:

```bash
curl http://127.0.0.1:8000/
```

Lihat kamera:

```text
http://127.0.0.1:8000/camera_feed
```

## Architecture

Backend dibagi menjadi beberapa boundary:

```text
backend/
├── fastAPI/              # HTTP/WebSocket API layer
│   ├── main.py           # App bootstrap + FaceID/enrollment endpoints
│   ├── routes/           # Router modular
│   └── schemas/          # Pydantic response/request schemas
├── engine/               # Runtime camera loop dan realtime state
│   ├── camera_stream.py  # Camera orchestration, overlay, status bridge
│   └── mood.py           # Mood heuristic + stability tracker
├── faceid/               # Face identification, labels, LBPH training
├── src/drowsy/           # Pure drowsiness scoring logic
├── src/vision/           # Face landmark wrapper
├── dataset/              # Face sample images per driver
├── models/               # MediaPipe/LBPH model artifacts
└── profiles/             # Driver profile data
```

Clean-code rule yang dipakai:

- API layer tidak menghitung vision metric secara langsung.
- Runtime camera loop hanya mengorkestrasi frame, state, dan overlay.
- Drowsiness scoring disimpan di `src/drowsy/engine.py`.
- Mood scoring disimpan di `engine/mood.py`.
- FaceID training/labeling disimpan di `faceid/`.
- Dataset dan model tidak dicampur dengan logic aplikasi.

Detail tambahan ada di [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Main Flow

```text
Camera
-> FaceID recognition
-> Driver match gate
-> Face landmarks
-> EAR/MAR drowsiness analysis
-> Mood raw detection
-> Mood stable confirmation
-> /drowsiness_status for Flutter
```

Drowsiness dan mood hanya diupdate jika:

- Monitoring aktif.
- `driver_name` yang diminta Flutter cocok dengan driver yang dikenali kamera.
- Wajah frontal dan landmark valid.

Jika driver tidak cocok, status menjadi:

```json
{
  "status": "waiting_driver",
  "face_position": "not_target_driver",
  "driver_match": false
}
```

## Important Endpoints

Lihat daftar lengkap di [docs/API.md](docs/API.md).

```text
GET  /
GET  /camera_feed
GET  /capture_face
GET  /driver_status
GET  /drivers
POST /recognize
POST /enroll
POST /enroll_live_burst
POST /start_drowsiness
POST /stop_drowsiness
GET  /drowsiness_status
```

## Driver Enrollment

Daftar ulang driver dari live camera:

```bash
curl -X POST http://127.0.0.1:8000/enroll_live_burst \
  -F "driver_name=Febrian" \
  -F "duration_sec=8" \
  -F "target_samples=60"
```

Dataset tersimpan di:

```text
backend/dataset/<driver_name>/
```

Model LBPH akan dilatih ulang setelah enrollment berhasil.

Jika driver dihapus lewat `DELETE /driver/{name}`, folder dataset, label, dan model LBPH akan disinkronkan ulang supaya driver lama tidak tetap dikenali.

## Test Drowsiness + Mood

Pastikan backend berjalan, lalu:

```bash
python backend/test_mood_detection.py --driver Febrian
```

Output penting:

```text
target=Febrian
recognized=Febrian
match=True
drowsy=normal
mood=happy
raw=happy
hold=7.1/7.0s
```

`raw_mood` adalah mood langsung dari frame. `mood` adalah mood yang sudah stabil sesuai durasi konfirmasi.

## Mood Thresholds

Mood berada di `backend/engine/mood.py`.

Default:

```python
MoodConfig(
    confirm_seconds=7.0,
    neutral_confirm_seconds=2.0,
)
```

Interpretasi:

- `happy` atau `sad` harus stabil 7 detik sebelum confirmed.
- `neutral` cukup stabil 2 detik.
- `raw_mood` tetap dikirim agar Flutter bisa menampilkan progres.

## Development Notes

- Jalankan server dari root repository agar import `backend.*` stabil.
- Jangan hapus dataset/model tanpa sengaja karena berisi hasil enrollment.
- Nyalakan log detail camera loop hanya saat debugging dengan `BACKEND_DEBUG_CAMERA=1`.
- Setelah mengubah logic FaceID/enrollment, test `/driver_status`.
- Setelah mengubah drowsiness/mood, test `/drowsiness_status` dan `backend/test_mood_detection.py`.
- Untuk perubahan Flutter yang memakai status backend, pastikan `driver_match=true`.
