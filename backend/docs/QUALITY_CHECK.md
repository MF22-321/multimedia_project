# Backend Quality Check

Dokumen ini mencatat skenario QC backend yang dapat diulang. Automated test tidak
membuka kamera dan tidak mengubah dataset, label, profile, atau model FaceID.

## Menjalankan Automated Test

Dari root repository:

```bash
MPLCONFIGDIR=/tmp/matplotlib-qc \
  /home/multimedia/miniconda3/envs/multimedia/bin/python \
  -m unittest discover -s backend/tests -v
```

## Skenario Automated

| ID | Area | Skenario | Hasil yang diharapkan |
|---|---|---|---|
| BE-001 | Driver input | Nama memiliki spasi di awal/akhir | Nama dinormalisasi |
| BE-002 | Security | Nama kosong, `..`, slash, backslash | Ditolak dengan HTTP 400 |
| BE-003 | Metrics | EAR/MAR dengan landmark valid | Rasio dihitung benar |
| BE-004 | Metrics | Lebar mata/mulut nol | Menghasilkan 0, bukan crash |
| BE-005 | Drowsiness | Kalibrasi dengan EAR valid | Baseline sesi tersimpan |
| BE-006 | Drowsiness | Mata tertutup melewati threshold | Alert `closed_eye` aktif dan ditahan |
| BE-007 | Drowsiness | Dua yawn dalam window uji | Alert `yawn` aktif |
| BE-008 | Mood | Happy belum stabil selama threshold | Mood tetap `unknown` |
| BE-009 | Mood | Happy stabil melewati threshold | Mood menjadi `happy` |
| BE-010 | API | Start monitoring dengan nama valid | State aktif dan nama normal |
| BE-011 | API | Start monitoring dengan nama kosong | Ditolak dengan HTTP 400 |
| BE-012 | Camera | Capture sebelum frame tersedia | HTTP 503, backend tidak crash |
| BE-013 | Camera | Stream dimulai sebelum frame pertama tersedia | Menunggu lalu mengirim frame saat siap |
| BE-014 | API contract | Timing awal status dibanding konfigurasi runtime | Nilai kalibrasi dan mood konsisten |

## Hasil Eksekusi

Eksekusi automated test pada 20 Juni 2026: **13 test lulus, 0 gagal**.
Pengujian kamera fisik tetap berstatus manual karena device kamera tidak tersedia
di environment QC.

## Skenario Integrasi Manual

Skenario berikut memerlukan server, kamera, dan driver yang sudah terdaftar.

| ID | Skenario | Langkah ringkas | Hasil yang diharapkan |
|---|---|---|---|
| BE-101 | Health | `GET /` | HTTP 200 dan pesan backend aktif |
| BE-102 | Daftar driver | `GET /drivers` | HTTP 200 dan array `drivers` |
| BE-103 | Driver cocok | Start dengan nama terdaftar lalu lihat kamera | `driver_match=true` |
| BE-104 | Driver berbeda | Wajah berbeda dari target | Status `waiting_driver` |
| BE-105 | Mata tertutup | Tutup mata melewati konfigurasi | Status `drowsy`, alasan `closed_eye` |
| BE-106 | Mood stabil | Tahan ekspresi melewati threshold | `mood` berubah setelah waktu konfirmasi |
| BE-107 | Stop | `POST /stop_drowsiness` | `active=false`, status `inactive` |
| BE-108 | Burst invalid | Kirim durasi <= 0 atau target <= 0 | HTTP 422, tidak membuat data driver |
| BE-109 | Camera feed | Buka `GET /camera_feed` | Stream MJPEG tampil tanpa putus |
| BE-110 | WebSocket | Hubungkan `/ws/camera` | Frame JPEG diterima berkala |

Untuk observasi drowsiness dan mood selama pengujian manual:

```bash
/home/multimedia/miniconda3/envs/multimedia/bin/python \
  backend/test_mood_detection.py --driver Febrian --stop
```
