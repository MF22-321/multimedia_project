# Backend Architecture

Dokumen ini menjelaskan boundary backend agar pengembangan berikutnya tetap rapi.

## Goals

- Pisahkan API, camera runtime, face recognition, drowsiness scoring, dan mood scoring.
- Hindari logic vision berat di route FastAPI.
- Pastikan state realtime yang dipakai Flutter punya kontrak field yang jelas.
- Buat perubahan kecil bisa dites tanpa harus menjalankan seluruh Flutter app.

## Layers

### API Layer

Lokasi:

```text
backend/fastAPI/
```

Tanggung jawab:

- Membuat FastAPI app.
- Mendaftarkan route.
- Decode request upload/form.
- Mengembalikan response JSON atau stream.
- Tidak menghitung EAR, MAR, mood, atau FaceID score secara langsung.

File penting:

- `main.py`: bootstrap app, camera startup, FaceID/enrollment endpoints.
- `routes/drowsiness_routes.py`: start/stop/status drowsiness.
- `schemas/drowsiness_schema.py`: kontrak response drowsiness + mood.

### Runtime Engine Layer

Lokasi:

```text
backend/engine/
```

Tanggung jawab:

- Membuka kamera.
- Menjalankan loop realtime.
- Menyimpan latest frame dan status yang dibaca API.
- Mengorkestrasi FaceID, landmark extraction, drowsiness, mood, dan overlay.

File penting:

- `camera_stream.py`: runtime loop dan bridge state.
- `mood.py`: mood heuristic dan stability tracker.

### FaceID Layer

Lokasi:

```text
backend/faceid/
```

Tanggung jawab:

- Face crop dari MediaPipe landmarker.
- Label store.
- LBPH model training.
- Face recognizer runtime.
- Enrollment utility.

### Drowsiness Domain Layer

Lokasi:

```text
backend/src/drowsy/
```

Tanggung jawab:

- Mengubah EAR/MAR menjadi status kantuk.
- Kalibrasi baseline EAR.
- Yawn detection.
- Composite drowsiness score.

`DrowsinessEngine` tidak tahu tentang kamera, API, atau Flutter.

### Storage Artifacts

Lokasi:

```text
backend/dataset/
backend/models/
backend/profiles/
```

Tanggung jawab:

- `dataset/`: face samples per driver.
- `models/`: MediaPipe model dan LBPH model.
- `profiles/`: data profil/baseline driver.

## Runtime State

`camera_stream.py` menyimpan dua state utama.

`driver_status`:

```json
{
  "driver": "Febrian",
  "recognized": true,
  "confidence": 0.42,
  "bbox": [x, y, w, h]
}
```

`drowsiness_status`:

```json
{
  "active": true,
  "driver_name": "Febrian",
  "recognized_driver": "Febrian",
  "driver_match": true,
  "ear": 0.27,
  "mar": 0.14,
  "mood": "happy",
  "raw_mood": "happy",
  "mood_candidate_elapsed": 7.2,
  "status": "normal"
}
```

## Driver Match Gate

Drowsiness dan mood hanya update ketika:

```text
drowsiness_status.driver_name == driver_status.driver
```

Jika tidak cocok, backend tidak menghitung EAR/MAR/mood untuk driver tersebut. Ini mencegah status Febrian terisi oleh wajah driver lain.

## Clean-Code Rules For Future Work

- Tambah endpoint baru di `fastAPI/routes/` jika domainnya sudah cukup besar.
- Simpan request/response model di `fastAPI/schemas/`.
- Simpan logic perhitungan di module domain, bukan di route.
- Jangan membuat route memanggil OpenCV/MediaPipe secara langsung kecuali untuk decode/upload sederhana.
- Jangan mengubah dataset/model otomatis dalam refactor non-enrollment.
- Gunakan nama driver original untuk backend matching; lowercase hanya untuk key preferensi frontend.

## Suggested Next Refactor

Masih ada pekerjaan bertahap yang bisa dilakukan nanti:

- Pecah endpoint FaceID/enrollment dari `fastAPI/main.py` ke router `faceid_routes.py`.
- Buat dataclass untuk `driver_status` dan `drowsiness_status`.
- Tambahkan unit test untuk `engine/mood.py` dan `src/drowsy/engine.py`.
- Kurangi print realtime berlebihan dengan logger yang bisa dikonfigurasi.
