# Viewer Kendaraan 3D Stabil untuk Jetson Orin Nano

Tanggal implementasi dan verifikasi: 7 Agustus 2026

## Hasil

Project multimedia memiliki viewer kendaraan 3D interaktif langsung di HMI
Flutter. Pengguna dapat memutar mobil dengan drag, melakukan pinch untuk zoom,
dan menekan tombol `360` untuk mengembalikan sudut awal.

Model yang ditampilkan berasal dari `toyota_veloz_2022.glb`. Renderer produksi
tidak memakai WebView, HMI kedua, atau external `Texture`. Mesh GLB diproses saat
build lalu digambar melalui `CustomPainter` Flutter agar stabil pada compositor
Linux dan driver NVIDIA Jetson yang digunakan.

## Arsitektur Produksi

```text
Vehicle3DViewer
  -> load assets/models/toyota_veloz_2022.sdtmesh
  -> gesture yaw / pitch / zoom
  -> Vehicle3DScenePainter
  -> transform, lighting, dan proyeksi vertex 3D
  -> depth bucket 11.423 triangle
  -> Canvas.drawVertices Flutter
  -> compositor HMI yang sama
```

Komponen utama:

| Komponen | Tanggung jawab |
|---|---|
| `vehicle_3d_viewer.dart` | Gesture, reset, badge, serta pemilihan renderer |
| `vehicle_3d_mesh.dart` | Validasi dan cache binary mesh `SDTMESH1` |
| `vehicle_3d_scene_painter.dart` | Proyeksi 3D, lighting, depth bucket, material, dan bayangan |
| `vehicle_3d_controller.dart` | Kontrak renderer native eksperimental |
| `tool/build_vehicle_mesh.cc` | Import GLB dan optimasi mesh memakai meshoptimizer |
| `vehicle_3d_texture.cc` | Renderer OpenGL/PixelBuffer eksperimental, bukan default Home |

Semua pemakaian `Vehicle3DViewer` menggunakan `useNativeTexture: false` secara
default. Mode native hanya aktif jika developer mengaturnya menjadi `true`
secara eksplisit.

## Akar Masalah Dot Hitam

Pengujian pada Jetson menemukan bahwa perubahan external `Texture` Flutter Linux
dapat membuat seluruh Home sesekali dipenuhi dot hitam. Masalah tetap muncul
setelah beberapa mitigasi berikut dicoba:

1. state OpenGL disimpan dan dikembalikan setelah render;
2. render dipindahkan dari context compositor Flutter ke shared `GdkGLContext`;
3. rotasi otomatis dan refresh texture kontinu dinonaktifkan;
4. output OpenGL dipindahkan ke empat buffer RGBA melalui
   `FlPixelBufferTexture`.

Percobaan keempat masih menghasilkan beberapa frame dot hitam ketika mobil
digeser. Ini membuktikan sumber masalah berada pada jalur komposisi external
texture pada kombinasi Flutter Linux, EGL, dan driver NVIDIA perangkat ini,
bukan pada mesh mobil atau gesture.

## Perbaikan Final

Jalur external texture dihapus dari renderer default. Mobil sekarang dibentuk
dari vertex tiga dimensi hasil import GLB, diputar menggunakan yaw dan pitch,
diproyeksikan ke koordinat layar, diurutkan dalam depth bucket, lalu dikirim ke
satu pemanggilan `Canvas.drawVertices` Flutter. Gesture dibatasi sekitar 30 FPS
agar pekerjaan proyeksi tidak membebani UI thread Jetson.

Drag dan pinch hanya me-repaint `RepaintBoundary` viewer. Tidak ada MethodChannel,
texture registrar, upload external texture, atau perubahan context OpenGL saat
mobil bergerak. Overlay AI juga tidak lagi mempertahankan texture video di dalam
opacity layer ketika overlay tidak terlihat.

Renderer native tetap disimpan untuk eksperimen engine/driver berikutnya, tetapi
tidak boleh diaktifkan kembali pada Home tanpa regression test frame-by-frame di
Jetson.

## Model Veloz GLB

File sumber `toyota_veloz_2022.glb` valid sebagai GLB versi 2 dengan 25 mesh,
25 material, dan 156.288 triangle. File tidak memuat image texture, animation,
atau skin; tampilan memakai warna material bawaan, pencahayaan dinamis, dan
bayangan dari renderer HMI.

Untuk menjaga kelancaran, build tool menyederhanakan mesh menjadi 11.423 triangle
(turun sekitar 92,7%), 34.269 expanded vertex, dan binary runtime sekitar 960 KB.
Panjang model dinormalisasi menjadi 4,4 unit, sumbu model disesuaikan menjadi
Y-up, dan warna 25 material dipertahankan. Jika asset gagal dimuat, procedural
vehicle lama tetap menjadi fallback sehingga Home tidak kosong.

Sumber model: Toyota Veloz 2022 oleh 241291joosje, Sketchfab, lisensi CC BY 4.0.
Attribution lengkap disimpan bersama asset di
`frontend/assets/models/TOYOTA_VELOZ_2022_ATTRIBUTION.md`.

## Regenerasi Asset Runtime

Tool membutuhkan header `nlohmann-json3-dev` dan library `meshoptimizer`. Contoh:

```bash
g++ -std=c++17 -O2 frontend/tool/build_vehicle_mesh.cc \
  -I/path/to/include -L/path/to/lib -Wl,-rpath,/path/to/lib \
  -lmeshoptimizer -o /tmp/build_vehicle_mesh

/tmp/build_vehicle_mesh \
  toyota_veloz_2022.glb \
  frontend/assets/models/toyota_veloz_2022.sdtmesh \
  0.06
```

Angka `0.06` adalah target rasio simplifikasi. File GLB asli tidak dibaca saat
HMI berjalan; HMI hanya membaca asset `.sdtmesh` yang sudah dioptimalkan.

## Build dan Menjalankan

Build release:

```bash
cd /home/multimedia/development/multimedia_project/frontend
/home/multimedia/flutter/flutter/bin/flutter build linux --release
```

Menjalankan HMI seperti biasa:

```bash
cd /home/multimedia/development/multimedia_project
FRONTEND_MODE=bundle ./startup.sh
```

Smoke test terisolasi tanpa mengganggu port TCP atau database HMI yang aktif:

```bash
cd /home/multimedia/development/multimedia_project/frontend/build/linux/arm64/release/bundle
MULTIMEDIA_TCP_PORT=0 \
HMI_ISOLATED_DATA_PATH=/tmp/sdt-hmi-gl-smoke \
./frontend --hmi-autostart-home
```

## Automated Check

```bash
cd /home/multimedia/development/multimedia_project/frontend
/home/multimedia/flutter/flutter/bin/flutter analyze --no-pub
/home/multimedia/flutter/flutter/bin/flutter test --no-pub \
  test/vehicle_3d_controller_test.dart
```

Test memastikan:

- asset hasil optimasi memiliki signature, ukuran, dan jumlah vertex valid;
- mode default memakai Canvas dan tidak membuat `Texture`;
- mode default tidak memanggil MethodChannel native;
- drag tetap tersedia pada renderer Canvas;
- mode native eksperimental masih dapat diinisialisasi dan memakai fallback;
- auto-rotation native tetap nonaktif secara default.

## Hasil Smoke Test Jetson

Simulasi melakukan 16 drag dan memutar kendaraan GLB melalui berbagai sudut.
Rekaman final memeriksa 120 frame selama gesture dan tidak menemukan dot
hitam atau frame Home yang rusak.

Pada crop background tetap, luminance hanya berubah dari `117,257` sampai
`117,355` dengan rentang `0,098`. Perubahan maksimum antar-frame hanya `0,039`.
Sebagai pembanding, renderer external texture sebelumnya memiliki rentang
`11,286` dan beberapa frame dot hitam pada skenario drag yang sama.

Hasil akhir:

- Flutter analyzer: tidak ada issue;
- test viewer/controller/mesh: 6 lulus, 0 gagal;
- build Linux ARM64 release: berhasil;
- 16 drag otomatis: stabil;
- 120/120 frame gesture: bebas dot hitam.
 