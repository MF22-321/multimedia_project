# Backend Development Guide

Panduan ini dipakai ketika menambah fitur atau merapikan backend.

## Local Run

Jalankan dari root repository:

```bash
cd /home/febrian/development/multimedia_project
conda activate drwosy
python -m uvicorn backend.fastAPI.main:app --host 127.0.0.1 --port 8000
```

## Smoke Test

```bash
curl http://127.0.0.1:8000/
curl http://127.0.0.1:8000/driver_status
curl http://127.0.0.1:8000/drowsiness_status
```

Test mood + drowsiness:

```bash
python backend/test_mood_detection.py --driver Febrian
```

## Syntax Check

```bash
PYTHONDONTWRITEBYTECODE=1 python -m py_compile \
  backend/engine/camera_stream.py \
  backend/engine/mood.py \
  backend/faceid/identifier.py \
  backend/faceid/labels_store.py \
  backend/fastAPI/main.py \
  backend/fastAPI/routes/drowsiness_routes.py \
  backend/fastAPI/schemas/drowsiness_schema.py \
  backend/test_mood_detection.py
```

## Clean-Code Checklist

Sebelum commit:

- Route FastAPI hanya melakukan parsing request dan memanggil service/runtime.
- Logic perhitungan disimpan di module domain.
- Field response baru dicatat di schema dan docs.
- Endpoint baru punya contoh request/response di `docs/API.md`.
- Perubahan mood/drowsiness dites dengan `test_mood_detection.py`.
- Perubahan enrollment dites dengan `/enroll_live_burst` dan `/driver_status`.
- Jangan commit file cache seperti `__pycache__/`.

## Debugging

Camera feed:

```text
http://127.0.0.1:8000/camera_feed
```

Jika `driver_match=false`:

- Pastikan `driver_name` dari Flutter sama persis dengan hasil `/driver_status`.
- Cek dataset di `backend/dataset/<driver_name>/`.
- Re-enroll driver jika FaceID sering `Unknown`.

Jika mood tidak berubah:

- Lihat `raw_mood` terlebih dahulu.
- Jika `raw_mood` berubah tapi `mood` belum berubah, tunggu sampai `mood_candidate_elapsed >= mood_required_sec`.
- Threshold dan durasi mood ada di `backend/engine/mood.py`.

Jika drowsiness tidak aktif:

- Cek `/drowsiness_status`.
- Pastikan `active=true`.
- Pastikan `face_position=frontal`.
- Pastikan `driver_match=true`.

Log detail camera loop sengaja dimatikan secara default. Untuk melihat detail pose, EAR/MAR, dan mood per frame:

```bash
BACKEND_DEBUG_CAMERA=1 python -m uvicorn backend.fastAPI.main:app --host 127.0.0.1 --port 8000
```
