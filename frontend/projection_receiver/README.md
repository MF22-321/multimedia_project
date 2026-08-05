# Android Auto wired receiver (Tahap 1)

Receiver ini mengambil stack Android Auto kabel/wireless dari LIVI dan menjalankannya
sebagai proses terpisah dari Flutter. Komunikasi dengan plugin Linux memakai
framing TCP lokal di `127.0.0.1:5281`; USB Android Auto sendiri tetap berjalan
di koneksi kabel melalui Android Open Accessory Protocol (AOAP).

Sumber vendor: LIVI commit `b7435e8db1fcc9b5280c45fb71d020d943577ef7`.
Folder `src/stack`, `src/protos`, helper `src/wireless_android_auto.py`, dan
`LICENSE-LIVI-GPL-3.0` mempertahankan
lisensi GPL-3.0-or-later dari proyek asal.

Runtime lokal dipasang oleh `scripts/setup_android_auto_receiver.sh` dan tidak
masuk Git. Receiver dibangun dengan `scripts/build_android_auto_receiver.sh`.
