# Face ID YuNet + SFace pada Jetson Orin Nano

Tanggal validasi: 6 Agustus 2026

## Ringkasan hasil

Face recognition utama sudah dipindahkan dari LBPH ke pipeline OpenCV YuNet +
SFace. LBPH tetap dibuat saat enrollment hanya sebagai opsi rollback eksplisit,
bukan fallback otomatis. Keputusan ini penting: hasil SFace yang ditolak tidak
boleh diam-diam diterima model lama yang lebih lemah.

Pipeline aktif:

```text
kamera
  -> YuNet mendeteksi wajah + 5 landmark
  -> quality gate (ukuran, cahaya, blur, pose)
  -> alignCrop berdasarkan 5 landmark
  -> SFace menghasilkan embedding 128 dimensi
  -> peringkat multi-template top-K
  -> threshold kemiripan + margin identitas kedua
  -> liveness gerakan temporal
  -> voting/stabilisasi identitas
  -> driver login
```

Model berasal dari repositori resmi OpenCV Zoo:

- YuNet: https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet
- SFace: https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface
- Referensi API OpenCV: https://docs.opencv.org/4.11.0/d0/dd4/tutorial_dnn_face.html

## Mengapa lebih tahan perubahan wajah

Implementasi lama hanya melatih LBPH dari satu burst yang seragam. Pada dataset
Febrian yang diaudit, 40 foto berasal dari sesi yang sama dan rentang brightness
hanya sekitar 106,6–109,6. Model praktis menghafal tekstur lokal dari satu kondisi.
Setelah cuci muka, posisi duduk berubah, kamera berpindah, atau cahaya berubah,
jarak LBPH dapat langsung melewati threshold.

SFace membandingkan representasi identitas yang sudah disejajarkan. Enrollment
baru juga tidak menyimpan semua frame secara buta. Sampel harus lolos pemeriksaan:

- wajah cukup besar;
- tidak terlalu gelap atau terlalu terang;
- gambar tidak blur;
- yaw tidak terlalu ekstrem;
- deteksi YuNet cukup yakin.

Selama 12 detik UI memberi enam arahan: frontal, kiri, kanan, dagu naik, dagu
turun, dan gerakan natural/perubahan jarak. Kondisi disimpan pada nama sampel,
sehingga template setelah alignment tetap seimbang per kondisi. Maksimum default
adalah delapan template per kondisi dan pencocokan memakai rata-rata tiga skor
terbaik, bukan satu foto saja.

## Proteksi salah identitas

Identitas diterima hanya jika semua lapisan berikut lolos:

1. kualitas frame valid;
2. skor cosine SFace minimal `0.40`;
3. selisih skor kandidat terbaik terhadap kandidat kedua minimal `0.06`;
4. gerakan landmark temporal memenuhi liveness ringan;
5. hasil stabil memenuhi voting beberapa frame.

Threshold dapat diubah melalui environment variable, tetapi jangan dilonggarkan
berdasarkan satu orang saja. Kalibrasi aman memerlukan minimal dua identitas dan
probe dari sesi/hari yang berbeda.

Liveness saat ini adalah mitigasi foto statis, bukan Presentation Attack
Detection tersertifikasi. Untuk deployment keamanan tinggi tetap diperlukan
kamera IR/depth atau model PAD yang diuji dengan protokol serangan cetak,
replay video, dan layar ponsel.

## Adaptive update dengan persetujuan pengguna

Ketika wajah sudah dikenali dengan confidence tinggi tetapi kondisinya belum ada
di gallery, backend menyiapkan kandidat template. Kandidat tidak langsung
disimpan. Pada halaman Personalize pengguna dapat menekan `Check Face ID Update`
lalu `Improve Face ID` untuk menyetujuinya.

Endpoint yang dipakai:

```text
GET  /faceid/adaptive_candidate
POST /faceid/adaptive_candidate/approve
POST /faceid/adaptive_candidate/reject
GET  /enrollment_status
```

## Instalasi model dan rebuild

Dari root project:

```bash
cd /home/multimedia/development/multimedia_project
./scripts/setup_faceid_sface.sh
```

Script mengunduh model resmi, memverifikasi SHA-256, lalu membuat ulang template
dari dataset lokal. File model ONNX, foto wajah, label, profile, dan embedding
masuk `.gitignore` karena model besar dan data biometrik tidak boleh ikut push.

Setelah model tersedia, aplikasi tetap dijalankan seperti biasa:

```bash
./startup.sh
```

`startup.sh` memakai `FACEID_RECOGNIZER=sface` secara default. Untuk rollback
sementara:

```bash
FACEID_RECOGNIZER=lbph ./startup.sh
```

## Cara daftar ulang yang benar

1. Hapus driver lama dari UI agar dataset dan template lama ikut dibersihkan.
2. Pilih tambah driver dan gunakan nama yang ingin disimpan.
3. Pastikan wajah memenuhi sebagian besar preview dan pencahayaan kabin normal.
4. Ikuti teks frontal/kiri/kanan/atas/bawah secara perlahan.
5. Jangan menggoyang kamera; gerakkan kepala dan ubah jarak sedikit.
6. Enrollment baru berhasil jika minimal 12 sampel berkualitas diterima.
7. Uji login setelah menjauh, berpindah sedikit, dan pada cahaya lebih redup.
8. Jika kondisi baru menghasilkan kandidat, setujui dari Personalize.

Untuk ketahanan lebih baik, tambahkan sesi kedua dengan nama driver yang sama
pada hari atau kondisi cahaya berbeda. Jangan mendaftarkan kondisi ekstrem yang
tidak menyerupai posisi mengemudi normal.

## Kalibrasi dan benchmark

Kalibrasi dataset lokal:

```bash
/home/multimedia/miniconda3/envs/multimedia/bin/python \
  backend/src/calibrate_sface.py
```

Benchmark deteksi + alignment + embedding:

```bash
/home/multimedia/miniconda3/envs/multimedia/bin/python \
  backend/src/benchmark_sface.py --iterations 100
```

Hasil Jetson pada satu sampel lokal:

| Metrik | Hasil |
|---|---:|
| Backend | CPU OpenCV DNN |
| Iterasi terdeteksi | 100/100 |
| Median | 28,985 ms |
| P95 | 31,839 ms |
| Throughput inferensi | 34,73 FPS |

Hasil dataset Febrian sebelum enrollment ulang:

| Metrik | Hasil |
|---|---:|
| Identitas | 1 |
| Foto/embedding | 40 |
| Genuine pairs | 780 |
| Genuine minimum | 0,8885 |
| Genuine P05 | 0,9308 |
| Genuine median | 0,9676 |
| Impostor pairs | 0 |

Skor internal satu identitas terlihat konsisten, tetapi ini belum mengukur False
Accept Rate karena belum ada pembanding orang lain. Jalankan kalibrasi ulang
setelah minimal dua driver dan beberapa sesi tersedia.

## Konfigurasi utama

| Variable | Default | Fungsi |
|---|---:|---|
| `FACEID_RECOGNIZER` | `sface` | Model aktif; `lbph` untuk rollback |
| `FACEID_SFACE_THRESHOLD` | `0.40` | Skor cosine minimum |
| `FACEID_SFACE_MARGIN` | `0.06` | Jarak minimum dari identitas kedua |
| `FACEID_SFACE_TOP_K` | `3` | Template terbaik yang dirata-rata |
| `FACEID_DETECT_THRESHOLD` | `0.75` | Confidence deteksi YuNet |
| `FACEID_MIN_SHARPNESS` | `35` | Batas blur enrollment/login |
| `FACEID_REQUIRE_LIVENESS` | `1` | Aktifkan liveness temporal |
| `FACEID_DNN_TARGET` | `cpu` | `cpu`, `cuda`, atau `cuda_fp16` |

Build OpenCV yang ada belum menyediakan target DNN CUDA, sedangkan modul Python
TensorRT belum tersedia. Karena CPU sudah mencapai sekitar 34,7 inferensi/detik,
target CPU dipakai sebagai default stabil. Jalur CUDA memiliki fallback aman ke
CPU. Optimasi TensorRT dapat dilakukan kemudian setelah binding TensorRT Python
dan engine yang sesuai versi JetPack tersedia.

## Automated quality gate

Jalankan:

```bash
./scripts/test_backend_quality.sh
```

Hasil akhir: 72 test backend lulus, 0 gagal, dengan 100% statement coverage
(1.353/1.353). Test SFace mencakup model hilang, CPU/CUDA fallback, deteksi,
alignment, seluruh quality gate, normalisasi embedding, gallery kosong,
threshold, ambiguous identity, top-K, deduplikasi/limit template, liveness,
adaptive approve/reject, build dataset, dan rollback model.

Coverage 100% membuktikan seluruh statement pada scope dieksekusi oleh test; ini
bukan klaim akurasi biometrik 100%. Akurasi nyata tetap harus dinilai dengan
driver berbeda, sesi berbeda, False Accept Rate, False Reject Rate, dan uji
kamera fisik.
