# Pothole Detector ESP32

Firmware mengirim telemetry lengkap ke backend setiap 500 ms. Setiap payload
selalu memiliki kategori `normal`, `bumper`, atau `pothole`; pengiriman tidak
lagi menunggu event.

Di dalam setiap interval, firmware menahan kategori dengan prioritas tertinggi
(`pothole` lalu `bumper` lalu `normal`) beserta severity puncaknya. Benturan
singkat tidak hilang hanya karena terjadi di antara dua jadwal POST.

Kategori event juga ditahan pada USB serial selama 1,5 detik agar Flutter
menerima cukup frame untuk membuat marker walaupun jadwal POST dan serial
bertepatan.

## Serial Contract

```text
GPS,lat,lng,speed,heading,pitch,roll,ax,ay,az,category,severity,wifiConnected,gpsFix,satellites,wifiSsid
```

- `heading` memakai course GPS saat kecepatan minimal 3 km/h.
- Heading terakhir ditahan saat kendaraan berhenti agar ikon tidak berbalik.
- Heading BNO055 hanya menjadi fallback sebelum course GPS tersedia.
- `ax`, `ay`, `az` adalah linear acceleration BNO055 untuk deteksi benturan,
  bukan sumber arah navigasi.
- USB serial tetap mengirim data ketika GPS belum fix atau Wi-Fi offline.
- Wi-Fi melakukan reconnect non-blocking di background; POST server hanya
  berjalan saat Wi-Fi tersambung dan GPS fix memiliki minimal 4 satelit.

## Kategori

```text
normal:  speed < 3 km/h atau severity di bawah threshold
pothole: speed >= 8 km/h dan severity >= 4.0
bumper:  speed <= 25 km/h dan severity >= 2.0
```

Pothole diprioritaskan sebelum bumper pada kondisi yang memenuhi keduanya.

## Wi-Fi Setup

Access point selalu aktif bersamaan dengan koneksi Wi-Fi utama:

```text
SSID: Pothole-ESP32-Setup
Password: 12345678
URL: http://192.168.4.1/
```

Portal memakai captive DNS. Jika popup setup tidak muncul otomatis, buka URL
di atas secara manual. ESP32 hanya mendukung jaringan 2.4 GHz.

## Build

```bash
pio run
```

## Automated Quality Test

Algoritma klasifikasi event dipisahkan dari driver Arduino sehingga dapat
diuji di host tanpa board. Quality gate juga menguji parser serial Flutter,
model/API pothole, routing, dan kalkulasi maps. Coverage minimum adalah 90%.

```bash
cd /home/multimedia/development/multimedia_project
./scripts/test_pothole_quality.sh
```

Test native memverifikasi threshold kecepatan dan impact, durasi event,
klasifikasi `normal`/`bumper`/`pothole`, timeout, reset state, prioritas kategori,
serta normalisasi dan smoothing heading. Langkah terakhir membangun firmware
ESP32 produksi dengan PlatformIO.
