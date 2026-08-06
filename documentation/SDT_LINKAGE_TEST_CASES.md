# Test Case dan Quality Gate SDT Linkage Multimedia

## 1. Tujuan dan batas klaim

Dokumen ini menjadi standar pengujian software untuk proyek Multimedia SDT Linkage pada Jetson Orin Nano. Status **LULUS** pada automated test berarti logika, kontrak data, error handling, dan integrasi antarmodul yang dapat disimulasikan telah bekerja sesuai skenario. Status tersebut tidak otomatis membuktikan akurasi AI di dunia nyata, kestabilan perangkat keras, atau performa kendaraan.

Automated test di proyek ini menggunakan mock/fake untuk kamera, wajah, HTTP backend, USB, TCP, Bluetooth, file model, dan dataset. Karena itu test aman dijalankan berulang kali dan tidak mendaftarkan, menghapus, atau mengubah wajah asli di `backend/dataset`.

## 2. Cara menjalankan

Jalankan seluruh quality gate dari root proyek:

```bash
cd /home/multimedia/development/multimedia_project
./scripts/test_sdt_linkage_acceptance.sh
```

Jalankan kelompok tertentu:

```bash
./scripts/test_backend_quality.sh

cd frontend
/home/multimedia/flutter/flutter/bin/flutter test --no-pub

cd projection_receiver
PATH=/home/multimedia/development/multimedia_project/.tools/node-v24.18.0-linux-arm64/bin:$PATH npm test

cd /home/multimedia/development/multimedia_project
FLUTTER_BIN=/home/multimedia/flutter/flutter/bin/flutter ./scripts/test_pothole_quality.sh
```

## 3. Kriteria kelulusan umum

| Kriteria | Target | Alasan |
|---|---:|---|
| Automated test | 100% test lulus | Satu kegagalan dapat menunjukkan regresi fungsi |
| Coverage modul kritis backend | minimal 90% | Menjaga cabang logika Face ID, drowsiness, dan mood tetap diuji |
| Coverage target pothole/maps Flutter | minimal 90% | Menjaga parsing, deteksi, dan navigasi tetap diuji |
| Coverage algoritma ESP32 native | minimal 90% | Menjaga keputusan road-event dan cooldown tetap diuji |
| Flutter analyzer | 0 error | Mencegah masalah tipe dan API sebelum runtime |
| TypeScript type-check/build | 0 error | Memastikan receiver Android Auto dapat dibangun |
| Data produksi | tidak berubah | Test otomatis harus terisolasi dan repeatable |

## 4. Test case Face Recognition, daftar, login, dan hapus akun

| ID | Skenario | Input/kondisi | Hasil yang diharapkan | Jenis |
|---|---|---|---|---|
| AUTH-001 | Backend hidup | Panggil `/` | Pesan backend berjalan | Auto |
| AUTH-002 | Ambil daftar akun | Folder Alya dan Budi tersedia | API `/drivers` hanya mengembalikan direktori akun | Auto |
| AUTH-003 | Daftar satu foto berhasil | Nama valid, foto valid, wajah terdeteksi, training berhasil | Sampel disiapkan, label dibuat, recognizer reload, rebuild embedding dijadwalkan | Auto |
| AUTH-004 | Daftar live burst berhasil | Kamera menghasilkan beberapa crop wajah | `saved_count` benar, label dibuat, training dan rebuild berjalan | Auto |
| AUTH-005 | Foto registrasi invalid | Byte bukan gambar | Registrasi gagal dengan `Invalid image` | Auto |
| AUTH-006 | Wajah tidak ditemukan | Gambar valid tanpa ROI wajah | Registrasi gagal dan label tidak dianggap berhasil | Auto |
| AUTH-007 | Gagal menyimpan sampel | `cv2.imwrite` gagal | Registrasi gagal dengan pesan penyimpanan | Auto |
| AUTH-008 | Data training belum cukup | Training LBPH tidak menghasilkan model | API melaporkan training gagal | Auto |
| AUTH-009 | Live burst tanpa wajah | Tidak ada crop selama periode capture | Registrasi gagal, `saved_count=0`, mode enrollment selalu dipulihkan | Auto |
| AUTH-010 | Kontrak multipart daftar | Nama dan byte foto dari Flutter | POST `/enroll`, field dan file benar | Auto |
| AUTH-011 | Kontrak live burst | Nama, durasi, target sampel | POST `/enroll_live_burst` dengan seluruh field benar | Auto |
| LOGIN-001 | Login wajah berhasil | Recognizer memberi nama terdaftar | Status `registered`, nama dan confidence dikembalikan | Auto |
| LOGIN-002 | Wajah tidak dikenal | Confidence/nama tidak memenuhi pengenalan | Status `unknown`, tidak menjadi akun lain | Auto |
| LOGIN-003 | Foto login invalid | Byte invalid | Login ditolak | Auto |
| LOGIN-004 | Auto-login dari HMI | Status recognized dan nama ada di daftar backend | Session disimpan dan HMI pindah ke Home | Auto |
| LOGIN-005 | Cegah stale identity | Recognizer memberi nama yang sudah tidak ada di daftar | Tidak login dan tetap pada pemilihan driver | Auto |
| LOGIN-006 | Login manual | Pengguna menekan kartu Alya | Nama dirapikan, session Alya, pindah Home | Auto |
| LOGIN-007 | Login tamu | Sebelumnya ada session driver | Session dibersihkan dan Home dibuka | Auto |
| LOGIN-008 | Backend offline | `/drivers` gagal | Loading berhenti, UI tidak crash, tambah akun tetap tersedia | Auto |
| AUTH-012 | Buka halaman registrasi | Tekan `Tambah Akun` | Route registrasi terbuka | Auto |
| AUTH-013 | Hapus akun berhasil | Dataset, profile, dan label tersedia | Semua artefak identitas dihapus, recognizer/state dibersihkan | Auto |
| AUTH-014 | Hapus akun tidak ada | Nama tidak terdapat pada data | Respons aman `Driver not found`, akun lain tidak berubah | Auto |
| AUTH-015 | Nama berbahaya | Kosong, `..`, slash, backslash | Validasi menolak dengan HTTP 400 | Auto |
| AUTH-M01 | Daftar wajah nyata | 5 pengguna, variasi sudut dan cahaya | Setiap pengguna dapat selesai daftar tanpa sampel orang lain | Manual |
| LOGIN-M01 | Uji akurasi nyata | Pengguna terdaftar dan orang asing | Hitung FAR, FRR, precision/recall; target proyek harus ditetapkan | Manual |
| LOGIN-M02 | Anti-spoof/liveness | Foto cetak/video wajah | Sistem harus menolak jika liveness menjadi requirement | Manual/gap |

## 5. Drowsiness dan mood detection

| ID | Skenario | Hasil yang diharapkan | Jenis |
|---|---|---|---|
| DROW-001 | Start untuk driver valid | Nama dinormalisasi, monitoring aktif | Auto |
| DROW-002 | Start nama kosong | Ditolak HTTP 400 | Auto |
| DROW-003 | Baca status | EAR, MAR, score, calibration, alert dan identity state memiliki tipe/default benar | Auto |
| DROW-004 | Stop monitoring | Monitoring tidak aktif | Auto |
| DROW-005 | Kamera/runtime gagal | Endpoint start/status/stop menjadi HTTP 500, bukan sukses palsu | Auto |
| DROW-006 | Kalibrasi EAR | Baseline hanya memakai sampel valid | Auto |
| DROW-007 | Mata tertutup | Durasi melewati threshold menghasilkan alert | Auto |
| DROW-008 | Menguap berulang | Jumlah yawn dan window menghasilkan alert sesuai konfigurasi | Auto |
| DROW-009 | Alert cooldown/hold | Alarm tidak spam dan tetap aktif selama hold | Auto |
| MOOD-001 | Mood belum stabil | Kandidat belum langsung dikonfirmasi | Auto |
| MOOD-002 | Mood stabil | Mood dikonfirmasi setelah waktu minimum | Auto |
| DROW-M01 | Pengemudi nyata | Kacamata/tanpa kacamata, siang/malam, head pose | Ukur sensitivity, specificity, false alarm/jam | Manual |
| MOOD-M01 | Ekspresi nyata | Dataset pengguna dan kondisi kabin representatif | Buat confusion matrix per kelas mood | Manual |

## 6. Pothole, ESP32, GPS, dan maps

| ID | Skenario | Hasil yang diharapkan | Jenis |
|---|---|---|---|
| POT-001 | Parse telemetri valid | Timestamp, GPS, accelerometer, gyro menjadi model bertipe benar | Auto |
| POT-002 | Paket rusak/parsial | Decoder menolak atau menunggu paket lengkap tanpa crash | Auto |
| POT-003 | Jalan normal | Tidak membuat pothole palsu | Auto |
| POT-004 | Impak melewati threshold | Event pothole dibuat dengan severity/lokasi | Auto |
| POT-005 | Cooldown | Satu impak tidak dihitung berkali-kali | Auto |
| POT-006 | Coverage algoritma firmware | Native ESP32 line/branch memenuhi gate | Auto |
| ESP-001 | Firmware production build | PlatformIO selesai tanpa error | Auto |
| MAP-001 | Konversi koordinat/rute | Titik dan urutan rute benar | Auto |
| MAP-002 | Navigasi maju/menyimpang | State dan instruksi diperbarui sesuai posisi | Auto |
| MAP-003 | Tile/config map | URL dan konfigurasi sumber peta valid | Auto |
| POT-M01 | Jalan nyata | Melewati lubang, polisi tidur, jalan bergelombang | Confusion matrix dan precision/recall dicatat | Manual |
| ESP-M01 | Sensor fisik | Putus serial, reboot, paket cepat, noise | HMI pulih otomatis dan tidak membeku | Manual |
| MAP-M01 | GPS fisik | Fix hilang, tunnel, urban canyon, reroute | Posisi/rute pulih dan tidak lompat berbahaya | Manual |

## 7. Android Auto, CarPlay, audio, USB, dan wireless

| ID | Skenario | Hasil yang diharapkan | Jenis |
|---|---|---|---|
| AA-001 | AOAP handshake | Ponsel berpindah ke Android Open Accessory dengan urutan benar | Auto |
| AA-002 | USB bulk IN/OUT | Byte diteruskan dua arah tanpa perubahan | Auto |
| AA-003 | TLS handshake/frame | Fragmentasi, reassembly, error dan secure-connect tertangani | Auto |
| AA-004 | Service discovery | Channel video, audio, input, sensor, navigasi diumumkan benar | Auto |
| AA-005 | Video channel | Codec/config/frame diteruskan benar | Auto |
| AA-006 | Audio channel | Paket audio, focus, ACK, drain dan error path tertangani | Auto |
| AA-007 | Input/touch | Event sentuh dan key event dikodekan benar | Auto |
| AA-008 | Mic/sensor/navigation/media | Setiap channel memproses request/response dan edge case | Auto |
| AA-009 | TCP wireless bridge | Listen/connect/disconnect/retry dan error tertangani | Auto |
| AA-010 | Deteksi BT/Wi-Fi MAC | Env, sysfs, fallback dan MAC invalid tertangani | Auto |
| AA-011 | Receiver build | TypeScript type-check dan build production lulus | Auto |
| AA-M01 | Kabel Android Auto | Colok/lepas berulang pada ponsel target | Connect stabil, UI fullscreen, touch benar | Manual |
| AA-M02 | Audio nyata | Musik 30 menit, next/pause/call/navigation prompt | Tidak putus, glitch, drift, atau delay awal abnormal | Manual |
| AA-M03 | Wireless Android Auto | Pair Bluetooth lalu Wi-Fi, reconnect setelah reboot | Discovery dan reconnect konsisten | Manual |
| AA-M04 | Stress projection | Maps + musik + DMS + pothole bersamaan | FPS, CPU/GPU/RAM, suhu dan underrun dalam batas | Manual |
| CP-M01 | Wired CarPlay | iPhone tersertifikasi dan receiver tersedia | Proyeksi, touch dan audio berjalan | Manual/gap |

## 8. Fitur HMI lainnya

| ID | Skenario | Hasil yang diharapkan | Jenis |
|---|---|---|---|
| HMI-001 | Action/voice parser | Variasi perintah valid dipetakan ke action yang tepat; input asing aman | Auto |
| HMI-002 | Smart fragrance | Level, mode, timeout, dan state serial sesuai aturan | Auto |
| HMI-003 | Tema pengguna | Simpan/muat/ubah tema terisolasi per session | Auto |
| HMI-004 | RJ45 TCP multimedia | Frame lengkap/parsial, reconnect, invalid packet dan lifecycle server | Auto |
| HMI-005 | Projection controller | Start/stop/status/error Android Auto dipantulkan ke UI | Auto |
| HMI-M01 | RJ45 fisik | Cabut/pasang kabel, peer reboot, trafik panjang | Reconnect tanpa restart HMI dan tidak kehilangan kontrol | Manual |
| HMI-M02 | Fragrance fisik | Aktuator/ESP32 dan seluruh level | Output aktual sesuai UI dan fail-safe bekerja | Manual |
| HMI-M03 | Boot endurance | 50 cold boot dan restart service | Tidak ada hang, race, atau state lama bocor | Manual |

## 9. Checklist evidence setiap rilis

- Simpan log automated quality gate beserta commit SHA dan tanggal.
- Catat versi JetPack/Ubuntu, Flutter, Node.js, Python, firmware ESP32, dan model AI.
- Simpan tabel perangkat uji: model ponsel, versi Android/iOS, kabel, display, kamera, GPS, dan board ESP32.
- Simpan hasil manual test berupa pass/fail, bukti foto/video/log, defect ID, dan retest.
- Jangan menyebut sistem “100% aman” hanya dari statement coverage. Coverage 100% berarti seluruh statement target pernah dieksekusi oleh test; bukan berarti semua kombinasi input, akurasi AI, hardware fault, cybersecurity, dan kondisi jalan sudah terbukti.
- Rilis hanya jika semua automated gate lulus dan tidak ada defect severity critical/high yang terbuka.

## 10. Definition of Done

Fungsi dinyatakan siap untuk demo SDT Linkage jika automated test dan build lulus, test manual perangkat yang relevan lulus, data produksi tidak berubah oleh test, hasil pengukuran terdokumentasi, dan kegagalan dapat dipulihkan tanpa membuat HMI berhenti. Untuk klaim siap produksi/kendaraan, tambahkan proses safety, cybersecurity, privacy, reliability/endurance, EMC, dan validasi kendaraan sesuai standar perusahaan.
