#!/usr/bin/python3
"""Generate customer acceptance and full-system test workbooks with LibreOffice UNO.

Run with the system Python because its UNO bindings are installed by LibreOffice:
    /usr/bin/python3 documentation/customer_acceptance/generate_workbooks.py
"""

from __future__ import annotations

import os
import subprocess
import time
from pathlib import Path

import uno
from com.sun.star.beans import PropertyValue


ROOT = Path(__file__).resolve().parent
PIPE_NAME = "multimedia_acceptance_workbooks"
PROFILE = Path("/tmp/multimedia_acceptance_libreoffice_profile")

NAVY = 0x17365D
BLUE = 0x2F75B5
LIGHT_BLUE = 0xD9EAF7
PALE_BLUE = 0xEAF3F8
TEAL = 0x0F6B78
GREEN = 0x70AD47
LIGHT_GREEN = 0xE2F0D9
ORANGE = 0xED7D31
LIGHT_ORANGE = 0xFCE4D6
RED = 0xC00000
LIGHT_RED = 0xF4CCCC
GOLD = 0xFFC000
LIGHT_GOLD = 0xFFF2CC
GRAY = 0x7F8C8D
LIGHT_GRAY = 0xE7E6E6
VERY_LIGHT_GRAY = 0xF5F7F9
WHITE = 0xFFFFFF
BLACK = 0x1F1F1F


def prop(name: str, value):
    item = PropertyValue()
    item.Name = name
    item.Value = value
    return item


def excel_col(index: int) -> str:
    result = ""
    index += 1
    while index:
        index, remainder = divmod(index - 1, 26)
        result = chr(65 + remainder) + result
    return result


def cell_name(col: int, row: int) -> str:
    return f"{excel_col(col)}{row + 1}"


def set_value(sheet, col: int, row: int, value) -> None:
    cell = sheet.getCellByPosition(col, row)
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        cell.Value = float(value)
    else:
        cell.String = "" if value is None else str(value)


def write_rows(sheet, start_row: int, rows: list[list | tuple]) -> None:
    if not rows:
        return
    width = max(len(row) for row in rows)
    normalized = [tuple(list(row) + [""] * (width - len(row))) for row in rows]
    target = sheet.getCellRangeByPosition(0, start_row, width - 1, start_row + len(rows) - 1)
    target.setDataArray(tuple(normalized))


def set_props(target, **properties) -> None:
    for name, value in properties.items():
        try:
            setattr(target, name, value)
        except Exception:
            pass


def border_line(color: int = 0xB7C9D6, width: int = 20):
    line = uno.createUnoStruct("com.sun.star.table.BorderLine2")
    line.Color = color
    line.LineWidth = width
    line.OuterLineWidth = width
    return line


def style_range(
    sheet,
    range_name: str,
    *,
    background: int | None = None,
    color: int | None = None,
    bold: bool | None = None,
    size: float | None = None,
    wrap: bool | None = None,
    center: bool = False,
    border: bool = False,
) -> None:
    target = sheet.getCellRangeByName(range_name)
    properties = {"CharFontName": "Aptos"}
    if background is not None:
        properties["CellBackColor"] = background
    if color is not None:
        properties["CharColor"] = color
    if bold is not None:
        properties["CharWeight"] = 150.0 if bold else 100.0
    if size is not None:
        properties["CharHeight"] = size
    if wrap is not None:
        properties["IsTextWrapped"] = wrap
    if center:
        properties["HoriJustify"] = 2
        properties["VertJustify"] = 2
    else:
        properties["VertJustify"] = 2
    if border:
        line = border_line()
        properties.update(
            TopBorder=line,
            BottomBorder=line,
            LeftBorder=line,
            RightBorder=line,
        )
    set_props(target, **properties)


def merge_title(sheet, last_col: int, title: str, subtitle: str | None = None) -> int:
    end = excel_col(last_col)
    sheet.getCellRangeByName(f"A1:{end}1").merge(True)
    set_value(sheet, 0, 0, title)
    style_range(
        sheet,
        f"A1:{end}1",
        background=NAVY,
        color=WHITE,
        bold=True,
        size=13,
        wrap=True,
        center=True,
    )
    sheet.Rows.getByIndex(0).Height = 1050
    if subtitle:
        sheet.getCellRangeByName(f"A2:{end}2").merge(True)
        set_value(sheet, 0, 1, subtitle)
        style_range(
            sheet,
            f"A2:{end}2",
            background=LIGHT_BLUE,
            color=NAVY,
            size=10,
            wrap=True,
            center=True,
        )
        sheet.Rows.getByIndex(1).Height = 720
        return 3
    return 2


def style_table(sheet, header_row: int, row_count: int, col_count: int) -> None:
    end_col = excel_col(col_count - 1)
    header = header_row + 1
    last = header_row + row_count
    style_range(
        sheet,
        f"A{header}:{end_col}{header}",
        background=BLUE,
        color=WHITE,
        bold=True,
        size=9,
        wrap=True,
        center=True,
        border=True,
    )
    sheet.Rows.getByIndex(header_row).Height = 1050
    if row_count > 1:
        style_range(
            sheet,
            f"A{header + 1}:{end_col}{last}",
            color=BLACK,
            size=9,
            wrap=True,
            border=True,
        )
        for row in range(header_row + 1, header_row + row_count):
            if (row - header_row) % 2 == 0:
                style_range(
                    sheet,
                    f"A{row + 1}:{end_col}{row + 1}",
                    background=VERY_LIGHT_GRAY,
                )
            sheet.Rows.getByIndex(row).OptimalHeight = True


def set_widths(sheet, widths: list[int]) -> None:
    for index, width in enumerate(widths):
        sheet.Columns.getByIndex(index).Width = width


def freeze(sheet, doc, col: int, row: int) -> None:
    try:
        doc.CurrentController.setActiveSheet(sheet)
        doc.CurrentController.freezeAtPosition(col, row)
    except Exception:
        pass


def add_autofilter(doc, sheet, name: str, range_name: str) -> None:
    try:
        address = sheet.getCellRangeByName(range_name).RangeAddress
        doc.DatabaseRanges.addNewByName(name, address)
        doc.DatabaseRanges.getByName(name).AutoFilter = True
    except Exception:
        pass


def add_list_validation(sheet, range_name: str, formula: str, title: str) -> None:
    try:
        target = sheet.getCellRangeByName(range_name)
        validation = target.Validation
        validation.Type = uno.Enum("com.sun.star.sheet.ValidationType", "LIST")
        validation.Formula1 = formula
        validation.ShowList = 1
        validation.ShowErrorMessage = True
        validation.ErrorTitle = "Pilihan tidak valid"
        validation.ErrorMessage = f"Pilih nilai yang tersedia untuk {title}."
        target.Validation = validation
    except Exception:
        pass


def set_formula(sheet, col: int, row: int, formula: str) -> None:
    sheet.getCellByPosition(col, row).Formula = formula


def add_sheet(doc, name: str):
    sheets = doc.Sheets
    if sheets.getCount() == 1 and sheets.getByIndex(0).Name == "Sheet1":
        sheets.getByIndex(0).Name = name
        return sheets.getByIndex(0)
    sheets.insertNewByName(name, sheets.getCount())
    return sheets.getByName(name)


def setup_document(desktop):
    doc = desktop.loadComponentFromURL(
        "private:factory/scalc",
        "_blank",
        0,
        (prop("Hidden", True),),
    )
    set_props(doc.DocumentProperties, Title="Multimedia Project Acceptance")
    return doc


def store_xlsx(doc, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    doc.storeAsURL(
        uno.systemPathToFileUrl(str(path)),
        (
            prop("FilterName", "Calc MS Excel 2007 XML"),
            prop("Overwrite", True),
        ),
    )


def acceptance_questions() -> list[tuple]:
    return [
        ("UAT-001", "Startup", "Apakah sistem dapat menyala dan menampilkan aplikasi tanpa error?", "Lakukan cold boot Jetson, tunggu sampai Boot Page tampil, lalu lanjutkan seluruh intro.", "Aplikasi tampil penuh, tidak hang/crash, dan urutan Boot → Warning → Ganjil/Genap → Pilih Driver berjalan."),
        ("UAT-002", "Warning", "Apakah informasi keselamatan mudah dipahami?", "Baca warning lalu tekan tombol persetujuan.", "Teks terbaca jelas, tombol responsif, dan hanya lanjut setelah customer menyetujui."),
        ("UAT-003", "Face Recognition", "Apakah driver terdaftar dikenali dengan benar?", "Hadapkan wajah driver terdaftar ke kamera pada jarak normal.", "Nama yang benar terdeteksi dan sistem otomatis membuka Home tanpa memilih akun lain."),
        ("UAT-004", "Face Recognition", "Apakah orang yang belum terdaftar ditolak dengan aman?", "Hadapkan wajah orang yang belum terdaftar.", "Tidak terjadi auto-login sebagai driver lain; halaman pemilihan driver tetap tampil."),
        ("UAT-005", "Tambah Driver", "Apakah proses pendaftaran driver baru mudah diikuti?", "Isi nama, ikuti panduan posisi wajah selama capture, lalu simpan.", "Progress sampel terlihat, registrasi berhasil, profil tersimpan, dan driver masuk ke Home."),
        ("UAT-006", "Tambah Driver", "Apakah sistem memberi pesan yang jelas untuk input tidak valid?", "Coba mulai registrasi tanpa nama dan saat wajah tidak terlihat jelas.", "Sistem menolak input kosong dan memberi panduan/peringatan tanpa crash."),
        ("UAT-007", "Pilih Driver", "Apakah login manual melalui kartu driver berfungsi?", "Tekan salah satu kartu driver terdaftar.", "Driver aktif sesuai kartu yang dipilih dan preferensinya dimuat."),
        ("UAT-008", "Guest", "Apakah mode tamu dapat digunakan tanpa membawa profil sebelumnya?", "Masuk sebagai guest setelah sebelumnya memakai akun driver.", "Home terbuka, sesi driver lama dibersihkan, dan data profil pribadi tidak tertukar."),
        ("UAT-009", "Profil", "Apakah preferensi driver tersimpan dan kembali dengan benar?", "Ubah fan, temperatur, fragrance, bahasa, dan tema; ganti driver lalu login kembali.", "Setiap preferensi kembali sesuai akun dan tidak memengaruhi akun lain."),
        ("UAT-010", "Hapus Akun", "Apakah penghapusan akun aman dan memerlukan verifikasi?", "Buka personalisasi, pilih hapus akun, verifikasi wajah, lalu konfirmasi.", "Akun hanya terhapus setelah verifikasi; dataset dan kartu driver hilang tanpa menghapus akun lain."),
        ("UAT-011", "Drowsiness", "Apakah monitoring kantuk mulai untuk driver aktif?", "Login sebagai driver dan aktifkan Peringatan Kantuk.", "Status monitoring aktif untuk nama driver yang benar dan tidak menghambat UI."),
        ("UAT-012", "Drowsiness", "Apakah peringatan kantuk muncul dan dapat dipahami?", "Gunakan skenario demo mata tertutup/menguap sesuai prosedur aman.", "Alert muncul sekali sesuai threshold, jelas, dapat ditutup, dan tidak spam."),
        ("UAT-013", "Mood & Musik", "Apakah rekomendasi musik berdasarkan mood relevan dan dapat dibuka?", "Tampilkan ekspresi happy/sad stabil sampai rekomendasi muncul, lalu tekan buka musik.", "Rekomendasi sesuai mood dan berpindah ke halaman Music dengan keyword yang tepat."),
        ("UAT-014", "Home", "Apakah navigasi Music, Phone, Home, Menu, dan Settings mudah digunakan?", "Buka kelima tab dari side menu secara berurutan.", "Tab aktif jelas, perpindahan halus, dan tidak ada elemen halaman lama yang bocor."),
        ("UAT-015", "Mobil 3D", "Apakah model mobil tampil utuh dan interaksinya lancar?", "Geser model 360°, ubah sudut vertikal, pinch zoom, lalu reset.", "Seluruh bagian mobil termasuk belakang tidak terpotong pada zoom normal; drag halus dan reset benar."),
        ("UAT-016", "Mobil 3D", "Apakah model 3D bebas glitch saat masuk Home?", "Dari Add Driver atau Driver Select, masuk ke Home beberapa kali.", "Model tidak muncul di halaman sebelumnya dan baru tampil setelah transisi Home selesai."),
        ("UAT-017", "Peta & GPS", "Apakah posisi kendaraan dan status GPS ditampilkan dengan benar?", "Hubungkan ESP32/GPS, tunggu fix, lalu bergerak pada rute aman.", "Koordinat, heading, kecepatan, dan posisi peta mengikuti data tanpa lompatan tidak wajar."),
        ("UAT-018", "Deteksi Jalan", "Apakah lubang/polisi tidur terdeteksi dan ditampilkan?", "Gunakan simulator atau lintasan uji aman untuk event bumper dan pothole.", "Kategori, severity, marker, dan notifikasi sesuai event; jalan normal tidak memicu alarm palsu."),
        ("UAT-019", "ESP32", "Apakah sistem pulih ketika ESP32 terputus dan tersambung kembali?", "Cabut USB ESP32 selama Home aktif, tunggu status berubah, lalu pasang kembali.", "UI tetap responsif, status disconnect jelas, dan telemetry pulih otomatis tanpa restart HMI."),
        ("UAT-020", "Music/Spotify", "Apakah pencarian dan kontrol musik bekerja?", "Cari lagu, play, pause, next, previous, dan seek.", "Metadata, artwork, posisi, dan status play mengikuti Spotify tanpa delay mengganggu."),
        ("UAT-021", "Lyrics", "Apakah lirik tampil dan tersinkron dengan lagu?", "Putar lagu yang memiliki lirik dan amati highlight baris.", "Lirik lagu yang benar tampil, dapat dibaca, dan mengikuti waktu playback."),
        ("UAT-022", "Radio", "Apakah radio dapat dipilih dan dikontrol?", "Buka Radio, pilih stasiun, play/pause, next, dan previous.", "Audio dan informasi stasiun sesuai pilihan; kontrol responsif."),
        ("UAT-023", "Bluetooth", "Apakah scan dan pairing perangkat mudah dilakukan?", "Aktifkan Bluetooth ponsel, scan, pairing, lalu disconnect.", "Perangkat ditemukan, status pairing benar, dan disconnect tidak membuat UI hang."),
        ("UAT-024", "USB", "Apakah perangkat USB terdeteksi dan informasinya benar?", "Pasang USB storage/audio, buka halaman USB, lalu connect/disconnect.", "Nama, kapasitas/status, dan aksi koneksi sesuai perangkat fisik."),
        ("UAT-025", "Android Auto Kabel", "Apakah Android Auto kabel siap digunakan customer?", "Hubungkan ponsel Android dengan kabel, setujui dialog, buka Maps/Music, coba touch dan audio.", "Video fullscreen stabil, touch tepat, audio keluar, dan disconnect mengembalikan ponsel ke MTP."),
        ("UAT-026", "Android Auto Wireless", "Apakah pairing dan proyeksi wireless berjalan?", "Pilih wireless, pairing Bluetooth, sambungkan ponsel ke hotspot, lalu jalankan Maps dan Music.", "Status tahapan jelas, video/touch/audio aktif, dan Wi-Fi sebelumnya dipulihkan setelah disconnect."),
        ("UAT-027", "CarPlay", "Apakah halaman dan koneksi CarPlay sesuai ruang lingkup?", "Buka Apple CarPlay dan hubungkan iPhone/perangkat receiver yang disepakati.", "Halaman tidak mencampur label Android Auto; hasil koneksi sesuai scope kontrak dan gap dicatat."),
        ("UAT-028", "Smart Fragrance", "Apakah pilihan aroma dan kekuatan sesuai output perangkat?", "Uji Coffee, Lavender, Both, Off, speed 1–3, Manual, dan Auto.", "Motor/aroma fisik sesuai pilihan UI, state feedback sinkron, dan Off mematikan seluruh output."),
        ("UAT-029", "Ambient Light", "Apakah pencahayaan kabin dapat dikontrol?", "Uji power, preset animasi, warna RGB, dan intensitas.", "Lampu fisik mengikuti UI; kegagalan MQTT menampilkan pesan dan tidak mengunci aplikasi."),
        ("UAT-030", "Theme", "Apakah tema bawaan dan custom konsisten?", "Uji Comfort, Eco, Sport, tema lain, warna custom, dan background image.", "Preview dan Home memakai tema terpilih; teks tetap terbaca dan tersimpan per driver."),
        ("UAT-031", "Settings", "Apakah volume dan bahasa bekerja serta tersimpan?", "Geser volume, ganti Bahasa/English, pindah halaman, lalu restart sesi.", "Volume sistem berubah, seluruh label relevan berganti bahasa, dan pilihan tersimpan."),
        ("UAT-032", "Video", "Apakah pemutar video memenuhi kebutuhan?", "Buka video, play/pause, seek, atur volume dan speed 0.75×/1×/1.25×, lalu tutup.", "Video dan audio sinkron, kontrol benar, dan resource dilepas setelah ditutup."),
        ("UAT-033", "RJ45/Remote", "Apakah perintah dari perangkat eksternal diterima dengan aman?", "Kirim perintah valid, paket terpotong, JSON invalid, cabut/pasang RJ45.", "Perintah valid dijalankan, input invalid ditolak dengan ACK error, dan koneksi pulih otomatis."),
        ("UAT-034", "Performance", "Apakah HMI terasa lancar pada beban penggunaan normal?", "Jalankan Maps, musik, DMS, telemetry ESP32, dan interaksi 3D selama minimal 30 menit.", "Touch tetap responsif, animasi mulus, audio tidak putus, dan tidak ada crash/throttling berlebih."),
        ("UAT-035", "Recovery", "Apakah sistem pulih dari backend/network yang restart?", "Restart backend dan matikan/nyalakan jaringan saat aplikasi berjalan.", "Aplikasi memberi status wajar, tidak crash, dan fungsi kembali tanpa reboot Jetson bila memungkinkan."),
        ("UAT-036", "Privasi", "Apakah penggunaan data wajah dan profil dapat diterima customer?", "Tinjau penyimpanan lokal, penghapusan akun, log, dan akses dataset.", "Customer memahami lokasi/purpose data; data dapat dihapus dan tidak tampil di log umum tanpa kebutuhan."),
        ("UAT-037", "Usability", "Apakah ukuran teks, kontras, dan target sentuh nyaman di head unit?", "Gunakan seluruh flow pada posisi duduk pengemudi/penumpang dalam kondisi terang dan gelap.", "Informasi utama terbaca cepat, tombol mudah disentuh, dan tidak ada kontrol penting terlalu kecil."),
        ("UAT-038", "Overall", "Apakah solusi secara keseluruhan memenuhi kebutuhan customer?", "Review hasil seluruh test, defect terbuka, batasan, dan kebutuhan tindak lanjut.", "Customer memberi keputusan Diterima/Diterima dengan Catatan/Ditolak beserta alasan dan sign-off."),
    ]


def build_acceptance_workbook(desktop, output: Path) -> None:
    doc = setup_document(desktop)

    identity = add_sheet(doc, "Petunjuk & Identitas")
    merge_title(
        identity,
        7,
        "CUSTOMER ACCEPTANCE TEST (CAT/UAT) — MULTIMEDIA PROJECT",
        "Identitas responden, hasil uji, respons customer, feedback, dan persetujuan akhir.",
    )
    identity_rows = [
        ["PETUNJUK PENGISIAN", ""],
        ["1", "Fasilitator mendemonstrasikan test sesuai kolom 'Skenario/Test yang Dilakukan'."],
        ["2", "Customer memberi respons bebas, nilai 1–5, status acceptance, catatan, dan bukti bila diperlukan."],
        ["3", "Status 'Diterima dengan Catatan' harus memiliki catatan dan bila perlu Defect/Feedback ID."],
        ["4", "Item N/A harus disertai alasan ruang lingkup. Keputusan akhir diisi pada sheet Sign-Off."],
        ["5", "Pengujian fisik dilakukan dalam kondisi aman; jangan membuat skenario kantuk atau jalan berbahaya saat berkendara umum."],
        ["", ""],
        ["IDENTITAS DOKUMEN & RESPONDEN", "NILAI / ISIAN"],
        ["Nama Proyek", "Multimedia Project — Jetson Orin Nano"],
        ["Nomor Dokumen", "CAT-MMP-001"],
        ["Versi Dokumen", "1.0"],
        ["Versi Build/Commit", ""],
        ["Tanggal Pengujian", ""],
        ["Lokasi Pengujian", ""],
        ["Nama Customer/Responden", ""],
        ["Jabatan/Peran", ""],
        ["Perusahaan/Departemen", ""],
        ["Email/No. Kontak", ""],
        ["Nama Fasilitator", ""],
        ["Nama Tester/QA", ""],
        ["Unit Jetson/Head Unit", ""],
        ["Perangkat Pendukung", "Kamera, ESP32, GPS, Android/iPhone, USB, fragrance, ambient light"],
        ["Waktu Mulai", ""],
        ["Waktu Selesai", ""],
    ]
    write_rows(identity, 3, identity_rows)
    identity.getCellRangeByName("A4:H4").merge(True)
    identity.getCellRangeByName("A11:H11").merge(True)
    style_range(identity, "A4:H4", background=TEAL, color=WHITE, bold=True, size=11)
    style_range(identity, "A11:H11", background=TEAL, color=WHITE, bold=True, size=11)
    for row in range(4, 10):
        identity.getCellRangeByName(f"B{row + 1}:H{row + 1}").merge(True)
    for row in range(11, 27):
        identity.getCellRangeByName(f"B{row + 1}:H{row + 1}").merge(True)
    style_range(identity, "A5:H10", background=PALE_BLUE, wrap=True, border=True)
    style_range(identity, "A12:H27", wrap=True, border=True)
    style_range(identity, "A12:A27", background=LIGHT_BLUE, bold=True)
    set_widths(identity, [3600, 4600, 2000, 2000, 2000, 2000, 2000, 2000])
    freeze(identity, doc, 0, 3)

    acceptance = add_sheet(doc, "Customer Acceptance")
    merge_title(
        acceptance,
        11,
        "FORMULIR CUSTOMER ACCEPTANCE",
        "Isi respons customer secara faktual. Nilai: 1=Sangat Tidak Puas, 2=Tidak Puas, 3=Cukup, 4=Puas, 5=Sangat Puas.",
    )
    headers = [
        "No.",
        "ID",
        "Area/Fitur",
        "Pertanyaan Acceptance",
        "Skenario/Test yang Dilakukan",
        "Hasil yang Diharapkan",
        "Respons Customer",
        "Nilai (1–5)",
        "Status Acceptance",
        "Catatan/Alasan",
        "Bukti/Defect ID",
        "Paraf",
    ]
    rows = [headers]
    for no, item in enumerate(acceptance_questions(), 1):
        test_id, area, question, scenario, expected = item
        rows.append([no, test_id, area, question, scenario, expected, "", "", "Belum Diuji", "", "", ""])
    write_rows(acceptance, 3, rows)
    style_table(acceptance, 3, len(rows), len(headers))
    set_widths(acceptance, [900, 1500, 2600, 5400, 6400, 6100, 5000, 1500, 3000, 4400, 2900, 1500])
    last_acceptance = 4 + len(acceptance_questions())
    add_list_validation(acceptance, f"H5:H{last_acceptance}", "$Referensi.$B$2:$B$6", "nilai")
    add_list_validation(acceptance, f"I5:I{last_acceptance}", "$Referensi.$A$2:$A$6", "status acceptance")
    add_autofilter(doc, acceptance, "AcceptanceTable", f"A4:L{last_acceptance}")
    freeze(acceptance, doc, 0, 4)

    feedback = add_sheet(doc, "Feedback Customer")
    merge_title(
        feedback,
        10,
        "FEEDBACK, CATATAN, DAN TINDAK LANJUT CUSTOMER",
        "Gunakan satu baris per feedback/masalah. Hubungkan ke ID acceptance atau test case bila tersedia.",
    )
    feedback_headers = [
        "No.", "Feedback ID", "Referensi ID", "Kategori", "Feedback/Temuan Customer",
        "Prioritas", "Respons Tim", "PIC", "Target Selesai", "Status", "Hasil Retest & Persetujuan Customer",
    ]
    feedback_rows = [feedback_headers]
    for no in range(1, 26):
        feedback_rows.append([no, f"FB-{no:03d}", "", "", "", "", "", "", "", "Open", ""])
    write_rows(feedback, 3, feedback_rows)
    style_table(feedback, 3, len(feedback_rows), len(feedback_headers))
    set_widths(feedback, [900, 1700, 1900, 2400, 6700, 1900, 5700, 2200, 2500, 2200, 5500])
    add_list_validation(feedback, "F5:F29", "$Referensi.$C$2:$C$5", "prioritas")
    add_list_validation(feedback, "J5:J29", "$Referensi.$D$2:$D$6", "status feedback")
    add_autofilter(doc, feedback, "FeedbackTable", "A4:K29")
    freeze(feedback, doc, 0, 4)

    signoff = add_sheet(doc, "Sign-Off")
    merge_title(
        signoff,
        7,
        "RINGKASAN DAN PERSETUJUAN AKHIR CUSTOMER",
        "Keputusan hanya ditandatangani setelah seluruh item in-scope selesai atau memiliki catatan/tindak lanjut yang disepakati.",
    )
    signoff_rows = [
        ["RINGKASAN HASIL", "JUMLAH"],
        ["Total item acceptance", ""],
        ["Diterima", ""],
        ["Diterima dengan Catatan", ""],
        ["Ditolak", ""],
        ["Belum Diuji", ""],
        ["N/A", ""],
        ["Rata-rata kepuasan (1–5)", ""],
        ["", ""],
        ["KEPUTUSAN CUSTOMER", ""],
        ["☐ DITERIMA", "Sistem diterima sesuai ruang lingkup dan kriteria yang disepakati."],
        ["☐ DITERIMA DENGAN CATATAN", "Sistem diterima dengan tindak lanjut pada Feedback/Defect Log."],
        ["☐ DITOLAK", "Sistem belum diterima; alasan dan syarat retest wajib ditulis."],
        ["Alasan/ketentuan keputusan", ""],
        ["Target retest (jika ada)", ""],
        ["", ""],
        ["PERNYATAAN", "Dengan menandatangani dokumen ini, para pihak menyatakan bahwa hasil uji dan catatan di workbook ini telah ditinjau bersama. Persetujuan tidak menghapus batasan keselamatan, privasi, atau defect yang masih terbuka."],
        ["", ""],
        ["PIHAK CUSTOMER", "PIHAK PROJECT/DEVELOPER"],
        ["Nama: ______________________________", "Nama: ______________________________"],
        ["Jabatan: ____________________________", "Jabatan: ____________________________"],
        ["Tanggal: ____________________________", "Tanggal: ____________________________"],
        ["Tanda tangan:                         ", "Tanda tangan:                         "],
        ["", ""],
        ["QA/WITNESS", "CATATAN QA"],
        ["Nama: ______________________________", ""],
        ["Tanggal: ____________________________", ""],
        ["Tanda tangan:                         ", ""],
    ]
    write_rows(signoff, 3, signoff_rows)
    for row in range(3, 31):
        signoff.getCellRangeByName(f"B{row + 1}:H{row + 1}").merge(True)
    for row in (3, 12, 21, 27):
        style_range(signoff, f"A{row + 1}:H{row + 1}", background=TEAL, color=WHITE, bold=True, size=11)
    style_range(signoff, "A4:H31", wrap=True, border=True)
    style_range(signoff, "A5:A11", background=LIGHT_BLUE, bold=True)
    style_range(signoff, "A14:H16", background=LIGHT_GOLD, bold=True)
    set_formula(signoff, 1, 4, "=COUNTA('Customer Acceptance'.B5:B42)")
    set_formula(signoff, 1, 5, '=COUNTIF(\'Customer Acceptance\'.I5:I42;"Diterima")')
    set_formula(signoff, 1, 6, '=COUNTIF(\'Customer Acceptance\'.I5:I42;"Diterima dengan Catatan")')
    set_formula(signoff, 1, 7, '=COUNTIF(\'Customer Acceptance\'.I5:I42;"Ditolak")')
    set_formula(signoff, 1, 8, '=COUNTIF(\'Customer Acceptance\'.I5:I42;"Belum Diuji")')
    set_formula(signoff, 1, 9, '=COUNTIF(\'Customer Acceptance\'.I5:I42;"N/A")')
    set_formula(signoff, 1, 10, '=IFERROR(AVERAGE(\'Customer Acceptance\'.H5:H42);0)')
    set_widths(signoff, [4300, 3200, 2200, 2200, 2200, 2200, 2200, 2200])
    freeze(signoff, doc, 0, 3)

    reference = add_sheet(doc, "Referensi")
    merge_title(reference, 4, "REFERENSI PILIHAN DAN DEFINISI")
    reference_rows = [
        ["Status Acceptance", "Nilai", "Prioritas", "Status Feedback", "Definisi"],
        ["Belum Diuji", "1", "Critical", "Open", "Item belum dilaksanakan."],
        ["Diterima", "2", "High", "In Progress", "Customer menerima tanpa catatan yang menghalangi."],
        ["Diterima dengan Catatan", "3", "Medium", "Ready for Retest", "Diterima dengan tindak lanjut yang disepakati."],
        ["Ditolak", "4", "Low", "Closed", "Hasil tidak memenuhi kebutuhan acceptance."],
        ["N/A", "5", "", "Deferred", "Di luar scope; alasan harus ditulis."],
    ]
    write_rows(reference, 2, reference_rows)
    style_table(reference, 2, len(reference_rows), 5)
    set_widths(reference, [3600, 1500, 2300, 2800, 6500])

    doc.Sheets.moveByName("Petunjuk & Identitas", 0)
    doc.CurrentController.setActiveSheet(identity)
    store_xlsx(doc, output)
    doc.close(True)


def system_test_cases() -> list[tuple]:
    cases: list[tuple] = []

    def add(test_id, module, submodule, priority, test_type, method, precondition, data, steps, expected):
        cases.append((test_id, module, submodule, priority, test_type, method, precondition, data, steps, expected))

    add("BOOT-001", "Startup", "Cold boot", "Critical", "Functional", "Manual", "Jetson mati; seluruh device terhubung", "Stopwatch", "1. Nyalakan Jetson\n2. Amati Boot Page\n3. Lanjutkan sampai Driver Select", "Urutan Boot → Warning → Ganjil/Genap → Driver Select selesai tanpa hang/crash.")
    add("BOOT-002", "Startup", "Warning consent", "High", "Functional", "Manual", "Boot Page selesai", "-", "1. Baca warning\n2. Jangan tekan tombol 5 detik\n3. Tekan setuju", "Tidak lanjut tanpa aksi; setelah setuju route berikutnya terbuka satu kali.")
    add("BOOT-003", "Startup", "Ganjil/Genap", "Medium", "Functional", "Manual", "Warning disetujui", "Tanggal kendaraan", "1. Verifikasi informasi ganjil/genap\n2. Tekan lanjut", "Teks/status sesuai desain dan halaman Driver Select terbuka.")
    add("BOOT-004", "Startup", "Backend offline", "High", "Negative/Recovery", "Hybrid", "Backend dihentikan", "Service backend off", "1. Jalankan HMI\n2. Masuk Driver Select\n3. Amati 30 detik", "Loading berhenti, UI tidak crash, Guest dan Tambah Akun tetap dapat diakses sesuai desain.")
    add("BOOT-005", "Startup", "Boot endurance", "High", "Reliability", "Manual", "Build release terpasang", "50 cold boot", "Ulangi cold boot 50 kali dan catat waktu/error", "100% boot selesai; tidak ada state lama bocor, hang, atau corruption.")

    add("BE-001", "Backend", "Health API", "Critical", "API", "Automated", "Backend aktif", "GET /", "Panggil health endpoint", "HTTP 200 dan pesan backend running.")
    add("CAM-001", "Camera", "MJPEG feed", "High", "Integration", "Manual", "Kamera aktif", "GET /camera_feed", "Buka stream selama 5 menit", "Frame bergerak stabil dan endpoint tidak berhenti.")
    add("CAM-002", "Camera", "WebSocket feed", "High", "Integration", "Hybrid", "Backend dan kamera aktif", "WS /ws/camera", "Buka halaman enrollment dan amati preview", "JPEG frame tampil realtime tanpa reconnect loop abnormal.")
    add("CAM-003", "Camera", "Capture face", "High", "API", "Automated", "Frame kamera tersedia", "GET /capture_face", "Panggil capture", "JPEG valid dikembalikan tanpa perubahan tak terduga.")
    add("CAM-004", "Camera", "Camera disconnect", "Critical", "Recovery", "Manual", "Preview aktif", "Cabut/pasang kamera", "1. Cabut kamera\n2. Tunggu status\n3. Pasang kembali", "Error ditangani; backend/HMI tidak crash dan stream pulih atau memberi instruksi restart jelas.")

    add("FACE-001", "Face Recognition", "Daftar driver", "Critical", "API/Functional", "Automated", "Dataset uji terisolasi", "GET /drivers", "Ambil daftar driver", "Hanya direktori akun valid dikembalikan dengan casing nama benar.")
    add("FACE-002", "Face Recognition", "Enrollment nama kosong", "High", "Negative", "Hybrid", "Halaman Add Driver terbuka", "Nama kosong", "Tekan Scan/Register tanpa nama", "Registrasi ditolak, pesan Name is required tampil, tidak ada dataset dibuat.")
    add("FACE-003", "Face Recognition", "Live burst sukses", "Critical", "Functional/AI", "Hybrid", "Kamera dan backend aktif; user belum terdaftar", "Nama valid; 12 detik; 30 sampel", "1. Isi nama\n2. Ikuti guidance\n3. Tunggu processing\n4. Simpan", "Sampel diterima cukup, model/embedding dibangun, driver terdeteksi dan profil tersimpan.")
    add("FACE-004", "Face Recognition", "Enrollment guidance", "High", "Usability/AI", "Manual", "Capture berlangsung", "Variasi terlalu gelap, blur, menoleh", "Ubah pose/cahaya selama capture", "accepted/rejected count dan guidance berubah wajar; sampel buruk tidak dianggap valid.")
    add("FACE-005", "Face Recognition", "Input foto invalid", "High", "Negative/API", "Automated", "Endpoint enroll tersedia", "Byte bukan gambar", "POST /enroll dengan file invalid", "HTTP error aman; tidak membuat label/model palsu.")
    add("FACE-006", "Face Recognition", "Tidak ada wajah", "High", "Negative/AI", "Automated", "Kamera mengarah ke area kosong", "Frame tanpa wajah", "Jalankan enrollment", "saved_count=0, registrasi gagal, mode enrollment dipulihkan.")
    add("FACE-007", "Face Recognition", "Auto-login valid", "Critical", "Functional/AI", "Hybrid", "Driver ada di /drivers", "Wajah driver terdaftar", "Hadapkan wajah sampai recognized", "Session memakai nama asli backend dan Home terbuka satu kali.")
    add("FACE-008", "Face Recognition", "Unknown face", "Critical", "Security/Negative", "Manual", "Orang belum terdaftar", "Wajah asing", "Hadapkan wajah asing 30 detik", "Tidak pernah login sebagai akun terdaftar; false accept dicatat.")
    add("FACE-009", "Face Recognition", "Stale identity", "Critical", "Negative", "Automated", "Recognizer mengembalikan nama yang sudah dihapus", "Nama tidak ada di /drivers", "Simulasikan recognized stale name", "HMI mengabaikan identity dan tetap di Driver Select.")
    add("FACE-010", "Face Recognition", "Login manual", "High", "Functional", "Automated", "Daftar driver tampil", "Kartu driver", "Tekan kartu driver", "Nama dirapikan, session benar, Home terbuka.")
    add("FACE-011", "Face Recognition", "Guest login", "High", "Functional", "Automated", "Sebelumnya ada driver session", "Guest", "Tekan Guest", "Session lama bersih dan Home terbuka tanpa identitas palsu.")
    add("FACE-012", "Face Recognition", "Hapus akun terverifikasi", "Critical", "Functional/Security", "Hybrid", "Driver aktif dan wajah cocok", "DELETE /driver/{name}", "1. Buka Delete Account\n2. Verifikasi wajah\n3. Konfirmasi", "Dataset, profile, label dan state identity akun itu terhapus; akun lain tetap utuh.")
    add("FACE-013", "Face Recognition", "Batal hapus akun", "High", "Functional", "Manual", "Dialog delete terbuka", "Cancel", "Tekan Cancel sebelum konfirmasi", "Tidak ada data/profile yang berubah.")
    add("FACE-014", "Face Recognition", "Validasi nama berbahaya", "Critical", "Security/Negative", "Automated", "Endpoint enrollment/delete", "Kosong, .., slash, backslash", "Kirim setiap nama invalid", "Ditolak HTTP 400; tidak ada akses path di luar dataset.")
    add("FACE-015", "Face Recognition", "Variasi kondisi nyata", "High", "AI Validation", "Manual", "Minimal 5 driver", "Terang/gelap, kacamata, sudut", "Uji tiap driver ≥20 percobaan", "Catat FAR, FRR, precision/recall per kondisi; target proyek terpenuhi.")
    add("FACE-016", "Face Recognition", "Anti-spoof/liveness", "Critical", "Security/Gap", "Manual", "Requirement liveness dikonfirmasi", "Foto cetak dan video wajah", "Coba login memakai media replay", "Ditolak bila liveness in-scope; jika belum ada, tandai gap dan risiko eksplisit.")

    add("PREF-001", "Driver Profile", "Simpan preferensi", "High", "Functional", "Automated", "Driver aktif", "Fan, suhu, fragrance, theme, language", "Ubah lalu simpan preference", "Seluruh field tersimpan pada key driver yang benar.")
    add("PREF-002", "Driver Profile", "Muat preferensi", "High", "Functional", "Automated", "Preference sudah disimpan", "Login ulang", "Ganti driver lalu kembali login", "UI memuat fan, suhu, cartridge, theme, custom colors dan bahasa yang sama.")
    add("PREF-003", "Driver Profile", "Isolasi antar-driver", "Critical", "Data Integrity", "Hybrid", "Dua driver dengan nilai berbeda", "Alya dan Budi", "Login bergantian dan bandingkan", "Preference tidak tertukar.")
    add("PREF-004", "Driver Profile", "Custom theme", "Medium", "Functional/UI", "Hybrid", "Driver aktif", "Gradient, accent, text, background image", "Buat custom theme, save, restart session", "Preview/Home konsisten, asset valid, teks terbaca, setting kembali.")
    add("PREF-005", "Driver Profile", "Adaptive Face ID approve", "High", "AI/Functional", "Hybrid", "Adaptive candidate tersedia", "Candidate wajah terbaru", "Approve candidate", "Embedding diperbarui hanya untuk driver aktif dan status sukses jelas.")
    add("PREF-006", "Driver Profile", "Adaptive Face ID reject", "High", "AI/Functional", "Hybrid", "Adaptive candidate tersedia", "Reject", "Reject candidate", "Candidate dibuang dan model utama tidak berubah.")
    add("PREF-007", "Driver Profile", "Ganti driver", "High", "Functional", "Automated", "Home aktif", "Settings → Ganti Driver", "Tekan Ganti Driver", "Drowsiness stop, session bersih, kembali Driver Select dan recognition aktif.")

    add("DMS-001", "Drowsiness", "Start monitoring", "Critical", "API/Integration", "Automated", "Driver aktif", "POST /start_drowsiness", "Start dengan nama driver", "Monitoring active=true dan nama target benar.")
    add("DMS-002", "Drowsiness", "Start nama kosong", "High", "Negative/API", "Automated", "Backend aktif", "driver_name kosong", "POST start", "HTTP 400; monitoring tidak aktif palsu.")
    add("DMS-003", "Drowsiness", "Kalibrasi EAR", "High", "AI", "Automated", "Wajah frontal valid", "Sampel EAR", "Jalankan fase calibration", "Baseline hanya memakai sampel valid dan calib_remaining turun benar.")
    add("DMS-004", "Drowsiness", "Mata tertutup", "Critical", "AI/Functional", "Hybrid", "Monitoring aktif dan calibrated", "Eye closed melewati threshold", "Simulasikan/ujikan mata tertutup", "score/status menjadi drowsy dan alert HMI tampil.")
    add("DMS-005", "Drowsiness", "Menguap berulang", "High", "AI/Functional", "Hybrid", "Monitoring aktif", "MAR/yawn sequence", "Lakukan yawn sesuai prosedur", "yawn count/window benar dan alert mengikuti konfigurasi.")
    add("DMS-006", "Drowsiness", "Alert hold/cooldown", "High", "Functional", "Automated", "Alert terpicu", "Event berulang", "Kirim event drowsy berturut-turut", "Alert tidak spam dan tetap aktif selama hold/cooldown yang ditetapkan.")
    add("DMS-007", "Drowsiness", "Toggle OFF", "Critical", "Functional/API", "Hybrid", "Monitoring aktif", "Settings switch OFF", "Matikan Peringatan Kantuk", "POST stop dipanggil; polling/alert berhenti.")
    add("DMS-008", "Drowsiness", "Toggle ON", "High", "Functional/API", "Hybrid", "Driver aktif; fitur OFF", "Settings switch ON", "Aktifkan kembali", "Monitoring restart untuk driver aktif tanpa duplikasi timer.")
    add("DMS-009", "Drowsiness", "Driver mismatch", "Critical", "Security/AI", "Automated", "Target driver A; kamera melihat B", "recognized_driver != driver_name", "Baca status", "driver_match=false, status waiting_driver, alert/rekomendasi tidak dikaitkan ke A.")
    add("DMS-010", "Drowsiness", "Kamera/runtime error", "Critical", "Recovery/API", "Automated", "Runtime dibuat gagal", "Exception camera", "Start/status/stop", "Backend mengembalikan error nyata, bukan sukses palsu; HMI tetap hidup.")
    add("MOOD-001", "Mood", "Candidate belum stabil", "Medium", "AI", "Automated", "Monitoring aktif", "Mood berubah singkat", "Kirim candidate < required_sec", "Mood confirmed tidak berubah terlalu cepat.")
    add("MOOD-002", "Mood", "Mood stabil", "High", "AI", "Automated", "Driver match", "Happy/sad stabil", "Pertahankan candidate sampai threshold", "Mood dikonfirmasi dengan confidence dan elapsed yang benar.")
    add("MOOD-003", "Mood", "Rekomendasi musik", "Medium", "Integration", "Hybrid", "Mood confirmed; driver_match=true", "happy/sad", "Tunggu dialog lalu pilih buka musik", "Keyword happy upbeat driving / calm relaxing night drive dikirim ke Music.")
    add("DMS-011", "Drowsiness", "Validasi fisik", "Critical", "AI Validation", "Manual", "Kondisi aman; driver peserta", "Kacamata, malam/siang, pose", "Jalankan protokol dataset representatif", "Sensitivity, specificity, false alarm/jam memenuhi target yang disepakati.")

    add("HMI-001", "Home/HMI", "Side navigation", "High", "Functional/UI", "Automated", "Home aktif", "Music/Phone/Home/Menu/Settings", "Buka 5 tab berurutan", "Index aktif, highlight, konten dan back behavior benar.")
    add("HMI-002", "Home/HMI", "App launcher", "High", "Functional/UI", "Manual", "Menu terbuka", "13 launcher apps", "Buka setiap tile dan kembali", "Setiap halaman benar, tidak ada dead-end/crash.")
    add("HMI-003", "Vehicle 3D", "Render model", "High", "Graphics", "Hybrid", "Home aktif", "Toyota Veloz mesh", "Amati model awal", "Mesh/material tampil utuh dengan transparansi/background benar.")
    add("HMI-004", "Vehicle 3D", "Rear clipping", "High", "Graphics/Regression", "Manual", "Model tampil", "Drag yaw 360° pada zoom default", "Geser model satu putaran penuh dan periksa semua sisi", "Depan/samping/belakang tidak terpotong oleh frame pada semua sudut normal.")
    add("HMI-005", "Vehicle 3D", "Route transition glitch", "Critical", "Graphics/Regression", "Hybrid", "Driver Select/Add Driver", "Transisi ke Home", "Masuk/keluar Home berulang 20 kali", "Native 3D tidak bocor ke route lain dan baru terlihat setelah bounds/animasi selesai.")
    add("HMI-006", "Vehicle 3D", "Gesture performance", "High", "Performance", "Manual", "Jetson release build", "Drag/pinch/reset", "Manipulasi 3D 2 menit sambil telemetry aktif", "Interaksi terasa lancar, update akhir akurat, UI lain tetap responsif.")
    add("HMI-007", "Vehicle", "Drive mode", "Medium", "Functional/UI", "Manual", "Vehicle page terbuka", "Comfort/Eco/Sport/Custom", "Pilih setiap mode", "Mode/highlight berubah benar dan tampilan tetap konsisten.")
    add("HMI-008", "Home/HMI", "Tanggal dan waktu", "Medium", "Functional", "Manual", "System clock benar", "Tanggal/waktu lokal", "Bandingkan top bar dengan OS", "Tanggal, hari dan waktu Asia/Jakarta benar.")

    add("GPS-001", "ESP32/GPS", "Serial frame valid", "Critical", "Protocol", "Automated", "Decoder aktif", "GPS extended telemetry", "Kirim satu frame lengkap", "Semua field lat/lng/speed/heading/impact/category/Wi-Fi/fix terparse benar.")
    add("GPS-002", "ESP32/GPS", "Frame parsial", "High", "Negative/Protocol", "Automated", "Decoder aktif", "Potongan byte", "Kirim frame dalam beberapa chunk", "Decoder menunggu newline dan hanya emit satu record lengkap.")
    add("GPS-003", "ESP32/GPS", "Frame rusak", "High", "Negative/Protocol", "Automated", "Decoder aktif", "Prefix/numeric invalid", "Kirim frame malformed", "Frame ditolak tanpa crash atau merusak frame berikutnya.")
    add("GPS-004", "ESP32/GPS", "GPS/Wi-Fi offline", "High", "Recovery", "Hybrid", "ESP32 via USB", "wifiConnected=false; gpsFix=false", "Matikan Wi-Fi/GPS", "USB telemetry tetap usable dan HMI menunjukkan status yang benar.")
    add("GPS-005", "ESP32/GPS", "USB reconnect", "Critical", "Recovery", "Manual", "HMI aktif", "Cabut/pasang ESP32", "Cabut 10 detik lalu pasang", "Serial auto-scan, status disconnect/reconnect dan data pulih tanpa restart.")
    add("POT-001", "Pothole", "Jalan normal", "Critical", "Algorithm", "Automated", "Firmware algorithm test", "speed/severity normal", "Kirim sampel normal", "Kategori normal dan tidak membuat marker palsu.")
    add("POT-002", "Pothole", "Bumper threshold", "High", "Algorithm", "Automated", "Firmware algorithm test", "speed ≤25; severity ≥2", "Kirim event", "Kategori bumper dengan severity benar.")
    add("POT-003", "Pothole", "Pothole threshold", "Critical", "Algorithm", "Automated", "Firmware algorithm test", "speed ≥8; severity ≥4", "Kirim event", "Kategori pothole diprioritaskan terhadap bumper.")
    add("POT-004", "Pothole", "Event hold", "High", "Algorithm/Integration", "Automated", "Event singkat terjadi", "Serial hold 1.5 detik", "Baca beberapa frame setelah impact", "Event bertahan cukup agar Flutter membuat marker tanpa duplicate tak wajar.")
    add("POT-005", "Pothole", "Marker realtime", "Critical", "Integration/UI", "Hybrid", "Pothole detection ON", "Telemetry event valid", "Kirim bumper/pothole", "Marker, severity dan notifikasi muncul pada lokasi yang benar.")
    add("POT-006", "Pothole", "Toggle OFF", "High", "Functional", "Hybrid", "Feature ON", "Settings toggle", "Matikan fitur lalu kirim event", "Tidak ada alert/marker baru ketika OFF.")
    add("POT-007", "Pothole", "Backend sync", "High", "Integration/API", "Hybrid", "ESP32 Wi-Fi dan GPS fix ≥4 satelit", "POST telemetry 500 ms", "Pantau request backend", "Payload kategori/severity/lokasi dikirim pada interval dan retry tidak memblokir serial.")
    add("POT-008", "Pothole", "Captive portal", "Medium", "Hardware/Usability", "Manual", "ESP32 baru/tidak punya Wi-Fi", "SSID Pothole-ESP32-Setup", "Connect 2.4 GHz, buka 192.168.4.1, simpan Wi-Fi", "Portal dapat dibuka, kredensial tersimpan, reconnect non-blocking.")
    add("MAP-001", "Maps", "Tile loading", "High", "Integration/UI", "Hybrid", "Internet/tile source aktif", "Lokasi valid", "Buka Home dan Map Detail", "Tile tampil; error jaringan tidak membuat peta blank permanen/crash.")
    add("MAP-002", "Maps", "Heading/position", "High", "Functional", "Hybrid", "GPS fix dan kendaraan bergerak", "speed ≥3 km/h", "Bandingkan course dengan arah peta", "Ikon/heading sesuai; heading terakhir stabil saat berhenti.")
    add("MAP-003", "Maps", "Route calculation", "Critical", "Functional/API", "Automated", "Origin/destination valid", "Koordinat rute", "Buat route", "Polyline, jarak, durasi dan urutan titik valid.")
    add("MAP-004", "Maps", "Reroute", "High", "Recovery/Functional", "Hybrid", "Navigasi aktif", "Penyimpangan rute", "Bergerak keluar koridor", "State menyimpang terdeteksi dan route/instruksi diperbarui aman.")
    add("MAP-005", "Maps", "GPS loss/recovery", "Critical", "Recovery", "Manual", "Navigasi aktif", "Tunnel/disable antenna", "Hilangkan fix lalu pulihkan", "UI menunjukkan loss, tidak lompat berbahaya, dan posisi pulih setelah fix.")
    add("POT-009", "Pothole", "Validasi jalan nyata", "Critical", "Hardware/AI Validation", "Manual", "Lintasan tertutup dan aman", "Lubang, polisi tidur, jalan bergelombang", "Jalankan beberapa pass pada variasi speed", "Confusion matrix/precision/recall memenuhi target; event false positive terdokumentasi.")

    add("MUS-001", "Music/Spotify", "Authentication/connect", "High", "Integration", "Manual", "Akun Spotify dan network", "Refresh token/device", "Buka Music dan connect", "Device/status Spotify tersedia atau error autentikasi jelas.")
    add("MUS-002", "Music/Spotify", "Search", "High", "Functional/API", "Hybrid", "Spotify connected", "Judul/artist valid dan invalid", "Cari musik", "Hasil relevan tampil; query kosong/error aman.")
    add("MUS-003", "Music/Spotify", "Playback controls", "Critical", "Functional", "Hybrid", "Track aktif", "Play/pause/next/previous", "Tekan setiap kontrol", "State, metadata dan audio mengikuti aksi tepat satu kali.")
    add("MUS-004", "Music/Spotify", "Seek/progress", "Medium", "Functional", "Manual", "Track aktif", "Slider position", "Geser ke 25%, 50%, 90%", "Playback pindah mendekati posisi dan progress kembali sinkron.")
    add("MUS-005", "Music/Spotify", "Lyrics", "Medium", "Integration/UI", "Hybrid", "Track dengan lirik", "Title/artist", "Putar lagu 2 menit", "Lirik benar, cache bekerja, baris sinkron dan fallback aman bila tidak tersedia.")
    add("MUS-006", "Music/Spotify", "Mood suggestion", "Medium", "Integration", "Hybrid", "MOOD-003 terpenuhi", "Suggested keyword", "Buka rekomendasi", "Search Music otomatis memakai keyword mood dan user tetap punya kontrol.")
    add("MUS-007", "Audio", "System volume", "High", "Hardware/Integration", "Manual", "Default sink tersedia", "0%, 30%, 70%, 100%", "Geser volume Settings", "PulseAudio/ALSA volume berubah sesuai nilai tanpa UI freeze.")
    add("RAD-001", "Radio", "Station controls", "Medium", "Functional", "Manual", "Internet aktif", "Daftar station", "Pilih, play/pause, next/previous", "Station/metadata/audio sesuai dan error stream tertangani.")
    add("VID-001", "Video", "Playback", "High", "Functional", "Manual", "Asset video tersedia", "Video produksi", "Open/play/pause/seek", "Video dan audio sinkron; posisi/controls benar.")
    add("VID-002", "Video", "Speed/volume/close", "Medium", "Functional", "Manual", "Video berjalan", "0.75×,1×,1.25×", "Uji speed, volume, lalu close", "Speed/audio state benar dan player/resource dilepas saat close.")

    add("BT-001", "Bluetooth", "Discovery", "High", "Hardware", "Manual", "Adapter Bluetooth aktif", "Ponsel discoverable", "Start scan", "Perangkat muncul satu kali dengan nama/MAC dan scan dapat dihentikan.")
    add("BT-002", "Bluetooth", "Pair/connect", "High", "Hardware", "Manual", "Device ditemukan", "PIN/confirmation", "Pair dan connect", "Status paired/connected benar dan tersimpan sesuai OS.")
    add("BT-003", "Bluetooth", "Disconnect/reconnect", "High", "Recovery", "Manual", "Ponsel connected", "Bluetooth toggle", "Disconnect, restart page, reconnect", "UI tidak hang dan status pulih.")
    add("PHONE-001", "Phone", "Phone page", "Medium", "Functional/UI", "Manual", "Home aktif", "Phone tab", "Buka Phone dan uji kontrol yang in-scope", "Label/empty state jelas; fitur yang belum terintegrasi tidak memberi sukses palsu.")
    add("USB-001", "USB", "Device detection", "High", "Hardware", "Manual", "USB dilepas", "Storage/audio USB", "Pasang USB dan buka page", "Device, storage dan connection status benar.")
    add("USB-002", "USB", "Connect audio", "Medium", "Hardware", "Manual", "USB audio tersedia", "Connect Audio", "Tekan connect", "Sink/audio USB diaktifkan atau error jelas.")
    add("USB-003", "USB", "Disconnect", "High", "Recovery", "Manual", "USB connected", "Disconnect button/cabut fisik", "Disconnect lalu cabut", "State bersih dan UI tetap stabil.")
    add("CAST-001", "Screen Cast", "ADB detection", "Medium", "Integration", "Manual", "Android USB debugging aktif", "adb devices", "Buka Screen Cast", "Device terdeteksi dan authorization state jelas.")
    add("CAST-002", "Screen Cast", "scrcpy lifecycle", "Medium", "Integration/Recovery", "Manual", "ADB authorized", "Start/stop cast", "Mulai lalu hentikan cast", "Proses tidak duplikat/zombie dan error ditampilkan.")
    add("RJ45-001", "RJ45/TCP", "Command ACK", "Critical", "Protocol/Integration", "Automated", "Listener 0.0.0.0:5050", "NDJSON command", "Kirim SOP/music/avatar reset", "Handler tepat dan ACK newline-delimited berisi request_id/status.")
    add("RJ45-002", "RJ45/TCP", "Invalid/partial JSON", "High", "Negative/Protocol", "Automated", "TCP connected", "Malformed dan partial frame", "Kirim data lalu frame valid", "Invalid mendapat ACK error; listener menerima frame berikut/reconnect.")
    add("RJ45-003", "RJ45/TCP", "Cable recovery", "Critical", "Hardware/Recovery", "Manual", "Peer 192.168.50.1 connected", "Cabut/pasang RJ45", "Putus 30 detik lalu sambung", "Listener/HMI tetap hidup dan peer dapat reconnect tanpa restart.")
    add("MQTT-001", "MQTT/AI", "Avatar commands", "Medium", "Protocol", "Automated", "MQTT/TCP handlers aktif", "avatar word/reset/state", "Kirim urutan command", "State/subtitle diapply berurutan dan reset benar.")
    add("AI-001", "AI Assistant", "Action parser", "High", "Functional/Negative", "Automated", "Parser aktif", "Perintah valid, alias, input asing", "Parse seluruh variasi", "Action valid dipetakan benar; input asing aman dan tidak mengeksekusi aksi lain.")

    add("AA-001", "Projection", "USB detection/AOAP", "Critical", "Hardware/Protocol", "Hybrid", "Samsung/Android dan kabel data", "04e8 MTP → 18d1 accessory", "Colok lalu pilih Android Auto Kabel", "Ponsel terdeteksi, AOAP handshake/re-enumeration dan service setup selesai.")
    add("AA-002", "Projection", "TLS/service discovery", "Critical", "Protocol", "Automated", "AOAP transport tersedia", "Session frames", "Jalankan handshake", "TLS, version, service discovery dan channel setup tidak error.")
    add("AA-003", "Projection", "Video/NVDEC", "Critical", "Graphics/Hardware", "Manual", "AA session running", "H.264 1280×720", "Buka Maps 15 menit", "Frame fullscreen stabil, decoder NVDEC/VIC diharapkan, tidak black/freeze.")
    add("AA-004", "Projection", "Touch input", "Critical", "Input/Hardware", "Manual", "Video AA tampil", "Down/move/up", "Tekan beberapa posisi dan swipe", "Koordinat tepat, tidak offset/double tap, ponsel merespons.")
    add("AA-005", "Projection", "Audio channels", "Critical", "Audio/Hardware", "Manual", "AA running", "Music 48k stereo; nav/system 16k mono", "Putar musik dan navigasi", "Audio keluar di sink default, prompt mix benar, tanpa startup glitch/drop abnormal.")
    add("AA-006", "Projection", "Disconnect to MTP", "High", "Recovery", "Manual", "AA aktif", "Disconnect", "Tekan Disconnect lalu cek lsusb", "Receiver berhenti bersih dan ponsel kembali MTP.")
    add("AA-007", "Projection", "Repeated reconnect", "High", "Reliability", "Manual", "Ponsel target", "20 connect/disconnect", "Ulangi koneksi 20 kali", "Tidak ada TLS stuck, zombie receiver, memory leak, atau gagal re-enumerasi.")
    add("AAW-001", "Projection", "Wireless setup", "Critical", "Hardware/Protocol", "Manual", "Bluetooth/Wi-Fi ponsel aktif", "Hotspot SDT Multimedia; WPP", "Pilih wireless, pair Bluetooth, setujui dialog", "WPP sukses, ponsel masuk hotspot, sesi TCP 5277 aktif.")
    add("AAW-002", "Projection", "Wireless media/input", "Critical", "Hardware", "Manual", "AA wireless aktif", "Maps/music/touch", "Gunakan 30 menit", "Video/audio/touch stabil setara kabel dalam batas latency yang disepakati.")
    add("AAW-003", "Projection", "Wi-Fi restoration", "High", "Recovery", "Manual", "Jetson sebelumnya terhubung internet", "Disconnect wireless", "Catat Wi-Fi sebelum, mulai AA, disconnect", "NetworkManager memulihkan koneksi Wi-Fi sebelumnya.")
    add("PROJ-001", "Projection", "Suspend/resume", "Medium", "Lifecycle", "Hybrid", "Projection running", "Suspend/Resume", "Tekan suspend lalu resume", "State dan texture/audio pause/resume tanpa sesi ganda.")
    add("PROJ-002", "Projection", "Simulator fallback", "Medium", "Fallback", "Automated", "Receiver native unavailable", "Simulation mode", "Start projection", "UI memberi label simulator dan tetap dapat diuji tanpa sukses native palsu.")
    add("CP-001", "Projection", "CarPlay page separation", "High", "UI/Regression", "Automated", "Menu tersedia", "Apple CarPlay", "Buka halaman CarPlay", "Tidak menampilkan label/kontrol Android Auto dan target controller benar.")
    add("CP-002", "Projection", "CarPlay physical", "High", "Hardware/Gap", "Manual", "Receiver/iPhone tersertifikasi tersedia", "iPhone target", "Hubungkan dan uji video/touch/audio", "Berfungsi sesuai scope; bila receiver belum tersedia, tandai N/A/gap, bukan Lulus.")
    add("PROJ-003", "Projection", "Stress", "Critical", "Performance", "Manual", "Jetson MAXN/production profile", "AA + DMS + ESP + audio", "Jalankan semua 60 menit", "FPS/audio stabil, CPU/GPU/RAM/suhu dalam target, tidak throttling/crash.")

    add("FRAG-001", "Smart Fragrance", "MQTT connection", "High", "Integration", "Manual", "Broker/device tersedia", "humidifier/control/state", "Buka page dan pantau status", "Connect/subscribe/publish sukses atau error jelas tanpa freeze.")
    add("FRAG-002", "Smart Fragrance", "Coffee shortcut", "High", "Functional/Hardware", "Hybrid", "Device connected", "Cartridge 1", "Pilih Coffee", "mainPower ON, motor1 ON speed 3, motor2 OFF.")
    add("FRAG-003", "Smart Fragrance", "Lavender shortcut", "High", "Functional/Hardware", "Hybrid", "Device connected", "Cartridge 2", "Pilih Lavender", "mainPower ON, motor1 OFF, motor2 ON speed 3.")
    add("FRAG-004", "Smart Fragrance", "Both/Off", "Critical", "Functional/Fail-safe", "Hybrid", "Device connected", "Both lalu Off", "Aktifkan keduanya lalu matikan", "Kedua motor sesuai Both; Off mematikan semua output.")
    add("FRAG-005", "Smart Fragrance", "Speed levels", "Medium", "Functional/Hardware", "Hybrid", "Motor aktif", "Level 1,2,3", "Uji tiap level tiap motor", "PWM/output fisik meningkat sesuai level dan state feedback sama.")
    add("FRAG-006", "Smart Fragrance", "Auto/manual", "High", "Functional", "Hybrid", "Main power ON", "Interval 10s dan manual", "Aktifkan auto lalu manual", "Siklus sesuai interval; manual menghentikan auto timer aman.")
    add("FRAG-007", "Smart Fragrance", "Invalid command", "Critical", "Negative/Fail-safe", "Automated", "Parser command aktif", "Cartridge/level invalid", "Kirim payload invalid", "Output memilih safe power-off/menolak; tidak mengaktifkan motor salah.")
    add("FRAG-008", "Smart Fragrance", "State synchronization", "High", "Integration", "Manual", "Device publish state", "humidifier/state", "Ubah state dari device", "UI detail realtime mengikuti device tanpa feedback loop.")

    add("AMB-001", "Ambient Light", "Power", "High", "Hardware/MQTT", "Manual", "Trainer kit connected", "ON/OFF", "Toggle power", "Lampu fisik dan UI state sesuai.")
    add("AMB-002", "Ambient Light", "Animation presets", "Medium", "Hardware/MQTT", "Manual", "Power ON", "Daftar preset", "Pilih setiap preset", "Animasi perangkat sesuai label dan tidak macet.")
    add("AMB-003", "Ambient Light", "RGB control", "High", "Hardware/MQTT", "Manual", "Power ON", "R/G/B min-mid-max", "Geser slider dan pilih swatch", "Warna fisik mendekati preview dan payload valid.")
    add("AMB-004", "Ambient Light", "Intensity", "Medium", "Hardware", "Manual", "Power ON", "0–100%", "Geser intensitas", "Brightness mengikuti nilai tanpa flicker berbahaya.")
    add("AMB-005", "Ambient Light", "MQTT failure", "High", "Negative/Recovery", "Manual", "Broker diputus", "Command ambient", "Kirim command saat offline lalu reconnect", "Snackbar gagal tampil; UI tidak mengaku sukses; fungsi pulih setelah reconnect.")

    add("SET-001", "Settings", "Drowsiness/Pothole toggles", "High", "Functional", "Hybrid", "Settings terbuka", "ON/OFF", "Toggle kedua fitur", "State global/API/provider mengikuti dan bertahan sesuai desain.")
    add("SET-002", "Settings", "Language Indonesian", "Medium", "Localization", "Manual", "Driver aktif", "Bahasa", "Pilih Bahasa dan buka seluruh menu utama", "String tersedia, layout tidak overflow, preference tersimpan.")
    add("SET-003", "Settings", "Language English", "Medium", "Localization", "Manual", "Driver aktif", "English", "Pilih English dan buka seluruh menu utama", "String benar, layout tidak overflow, preference tersimpan.")
    add("SET-004", "Settings", "Theme contrast", "High", "Accessibility/UI", "Manual", "Semua theme tersedia", "Comfort/Eco/Sport/Custom", "Buka halaman utama tiap theme", "Kontras, fokus, ikon dan teks penting tetap terbaca terang/gelap.")
    add("INFO-001", "Vehicle/Info", "Vehicle information", "Medium", "Functional/UI", "Manual", "Menu → Vehicle", "Fuel/battery/engine/status", "Buka page dan amati card", "Nilai/label sesuai source atau jelas sebagai demo; tidak ada data menyesatkan.")
    add("INFO-002", "Vehicle/Info", "Drive information", "Medium", "Functional/UI", "Manual", "Menu → Drive Info", "Analytics/detection/connectivity/system", "Buka seluruh section", "Informasi tampil konsisten dan dapat dibaca.")
    add("TUT-001", "Tutorial", "Guided help", "Low", "Usability", "Manual", "Menu → mToyota", "Tutorial pages", "Navigasi tutorial sampai akhir dan kembali", "Konten tersedia, navigasi tidak buntu.")

    add("NF-001", "Non-Functional", "UI responsiveness", "Critical", "Performance", "Manual", "Release build di Jetson", "Normal workload", "Ukur input latency/tab transition/3D selama 30 menit", "Tidak ada freeze; target latency/FPS proyek tercapai dan dicatat.")
    add("NF-002", "Non-Functional", "Memory endurance", "Critical", "Performance/Reliability", "Manual", "Monitoring tools aktif", "4 jam mixed use", "Jalankan musik, map, DMS, telemetry, projection bergantian", "RAM tidak tumbuh tanpa batas; tidak OOM/crash.")
    add("NF-003", "Non-Functional", "Thermal endurance", "Critical", "Hardware/Performance", "Manual", "Jetson power profile produksi", "2 jam peak workload", "Log suhu/clocks/throttling", "Suhu dan throttling berada dalam limit yang disepakati.")
    add("NF-004", "Non-Functional", "Backend restart", "Critical", "Recovery", "Manual", "HMI aktif", "Restart backend", "Stop/start backend ketika Home aktif", "HMI tidak crash; status pulih dan timer/request tidak berlipat.")
    add("NF-005", "Non-Functional", "Network offline", "High", "Recovery", "Manual", "Fitur online aktif", "Wi-Fi off 5 menit", "Matikan lalu pulihkan network", "Fitur lokal tetap bekerja; online error jelas; reconnect otomatis.")
    add("NF-006", "Non-Functional", "ESP32 reboot", "Critical", "Recovery", "Manual", "Telemetry aktif", "Reset board", "Reboot ESP32 10 kali", "Serial reconnect dan state normal kembali tanpa duplicate alert.")
    add("NF-007", "Non-Functional", "Power loss", "Critical", "Recovery/Data Integrity", "Manual", "Data test nonproduksi", "Hard power interruption", "Putus power saat idle dan saat save preference", "Filesystem/profile tidak korup; aplikasi boot kembali aman.")
    add("SEC-001", "Security/Privacy", "Face data access", "Critical", "Privacy Review", "Manual", "Akses Jetson", "Dataset/profile/model", "Review permission, lokasi, backup dan delete", "Akses dibatasi sesuai kebijakan; delete benar; retention/consent terdokumentasi.")
    add("SEC-002", "Security/Privacy", "Sensitive logging", "High", "Privacy Review", "Manual", "Release logs tersedia", "Nama/wajah/token/SSID", "Review log 30 menit dan file config", "Tidak ada secret/token/image wajah terekspos; data personal minimal dan beralasan.")
    add("SEC-003", "Security", "Network input validation", "Critical", "Security/Negative", "Hybrid", "API/TCP/MQTT accessible", "Malformed/oversized/replay", "Fuzz input terbatas sesuai izin", "Tidak crash/command injection/path traversal; error dan rate behavior aman.")
    add("NF-008", "Non-Functional", "Display scaling", "High", "Compatibility/UI", "Manual", "Target head unit", "Resolusi/scaling produksi", "Buka seluruh halaman pada display target", "Tidak overflow/crop; touch area sesuai visual; model 3D bounds benar.")
    add("NF-009", "Non-Functional", "Touch accuracy", "High", "Usability", "Manual", "Touchscreen terkalibrasi", "Grid target sudut/tengah", "Tekan target kecil/besar di seluruh area", "Aksi tepat, tidak offset/double trigger, target penting mudah dijangkau.")

    return cases


def e2e_use_cases() -> list[tuple]:
    return [
        ("UC-01", "Cold boot sampai Home", "Driver", "Jetson mati", "Nyalakan unit", "Boot → setujui warning → ganjil/genap → dikenali/pilih driver → Home", "Backend offline: login Guest; kamera gagal: pilih manual", "Home siap tanpa crash dan driver session benar"),
        ("UC-02", "Daftar driver baru", "Driver baru", "Backend/kamera aktif", "Pilih Tambah Akun", "Isi nama → capture burst → ikuti guidance → atur profil → simpan", "Nama kosong/wajah buruk/backend gagal ditolak jelas", "Driver baru ada di daftar dan dapat dikenali"),
        ("UC-03", "Auto-login driver", "Driver terdaftar", "Driver ada di backend", "Wajah terlihat kamera", "Recognition → validasi daftar → set session → load preference → Home", "Unknown/stale identity tidak login", "Tidak salah identitas dan preferensi benar"),
        ("UC-04", "Guest mode", "Tamu", "Driver session mungkin ada", "Tekan Guest", "Clear session → Home", "Backend offline tidak menghalangi", "Tidak ada profil driver lama yang bocor"),
        ("UC-05", "Monitoring kantuk", "Driver", "Login driver; DMS ON", "Home terbuka", "Start monitoring → calibrate → poll status → alert drowsy → dismiss", "Mismatch/no face/camera error", "Alert benar, tidak spam, dapat dinonaktifkan"),
        ("UC-06", "Mood ke musik", "Driver", "Mood stable; driver match", "Backend confirm happy/sad", "Dialog rekomendasi → user setuju → Music search keyword", "User menolak; mood belum stabil", "Kontrol tetap pada user dan lagu relevan dapat dipilih"),
        ("UC-07", "Navigasi dan pothole", "Driver", "GPS/ESP32 connected", "Pilih tujuan", "Hitung route → navigasi → telemetry event → marker/alert → lanjut/reroute", "GPS loss, Wi-Fi loss, serial reconnect", "Rute dan warning pulih tanpa UI freeze"),
        ("UC-08", "Android Auto kabel", "Driver + ponsel Android", "Kabel data dan receiver siap", "Pilih Android Auto Kabel", "AOAP → TLS → channels → fullscreen → maps/music/touch/audio → disconnect", "Handshake timeout, simulator fallback", "Session stabil dan kembali MTP setelah disconnect"),
        ("UC-09", "Android Auto wireless", "Driver + ponsel Android", "BT/Wi-Fi aktif", "Pilih Android Auto Wireless", "Hotspot → BT WPP → Wi-Fi TCP → projection → disconnect → restore Wi-Fi", "Pairing ditolak/timeout", "Status jelas dan jaringan sebelumnya pulih"),
        ("UC-10", "Smart fragrance", "Driver", "Broker dan actuator connected", "Buka Fragrance", "Pilih aroma → speed → auto/manual → state feedback → Off", "Broker/device offline; invalid command", "Output sesuai dan Off selalu fail-safe"),
        ("UC-11", "Ambient light", "Driver", "Trainer kit connected", "Buka Ambient Light", "Power → preset/RGB/intensity → state", "MQTT offline/reconnect", "Lampu sesuai UI dan tidak mengunci HMI"),
        ("UC-12", "Profil personal", "Driver", "Driver login", "Buka Personalize", "Ubah tema/preference/language → save → ganti driver → login kembali", "Cancel dan invalid background", "Persistensi terisolasi per driver"),
        ("UC-13", "Hapus akun", "Driver", "Driver login dan wajah tersedia", "Pilih Delete Account", "Verifikasi → konfirmasi → delete backend/local → Driver Select", "Cancel atau wajah mismatch", "Hanya akun terverifikasi terhapus"),
        ("UC-14", "Remote RJ45", "Raspberry Pi/peer", "RJ45 configured", "Peer connect dan kirim NDJSON", "Parse → route handler → action → ACK", "Partial/invalid packet; cable reconnect", "Perintah berurutan dan koneksi recoverable"),
        ("UC-15", "Mixed-use endurance", "Customer/QA", "Semua device aktif", "Mulai 4 jam test", "Music + maps + DMS + ESP + 3D + connect/disconnect projection/device", "Backend/network/device restart", "Tidak crash/leak; performa, suhu, dan bukti tercatat"),
    ]


def build_system_workbook(desktop, output: Path) -> None:
    doc = setup_document(desktop)
    cases = system_test_cases()

    summary = add_sheet(doc, "Ringkasan")
    merge_title(
        summary,
        9,
        "SYSTEM TEST — MULTIMEDIA PROJECT",
        "Test Jetson, Flutter HMI, backend AI, ESP32, projection, dan integrasi perangkat.",
    )
    summary_rows = [
        ["INFORMASI TEST RUN", "ISIAN"],
        ["Test Run ID", "MMP-TR-001"],
        ["Versi Build/Commit", ""],
        ["Tanggal Mulai", ""],
        ["Tanggal Selesai", ""],
        ["Test Lead", ""],
        ["Customer/Witness", ""],
        ["Environment", "Jetson Orin Nano / Linux Release Build"],
        ["", ""],
        ["DASHBOARD HASIL", "JUMLAH"],
        ["Total Test Case", ""],
        ["Lulus", ""],
        ["Gagal", ""],
        ["Blocked", ""],
        ["Belum Diuji", ""],
        ["N/A", ""],
        ["Pass Rate (tanpa N/A)", ""],
        ["Critical/High gagal atau blocked", ""],
        ["", ""],
        ["KRITERIA RELEASE", "TARGET"],
        ["Automated test", "100% lulus"],
        ["Flutter analyzer", "0 issue"],
        ["Build Linux release ARM64", "Berhasil"],
        ["Backend critical coverage", "≥90%"],
        ["Pothole/maps/ESP32 coverage", "≥90%"],
        ["Open defect Critical/High", "0"],
        ["Manual hardware in-scope", "100% Lulus atau waiver disetujui"],
    ]
    write_rows(summary, 3, summary_rows)
    for row in range(3, 30):
        summary.getCellRangeByName(f"B{row + 1}:J{row + 1}").merge(True)
    for row in (3, 12, 22):
        style_range(summary, f"A{row + 1}:J{row + 1}", background=TEAL, color=WHITE, bold=True, size=11)
    style_range(summary, "A4:J30", wrap=True, border=True)
    style_range(summary, "A5:A11", background=LIGHT_BLUE, bold=True)
    style_range(summary, "A14:A21", background=LIGHT_BLUE, bold=True)
    style_range(summary, "A24:A30", background=LIGHT_GOLD, bold=True)
    last_case_row = 4 + len(cases)
    set_formula(summary, 1, 13, f"=COUNTA('Master Test Cases'.B5:B{last_case_row})")
    set_formula(summary, 1, 14, f'=COUNTIF(\'Master Test Cases\'.M5:M{last_case_row};"Lulus")')
    set_formula(summary, 1, 15, f'=COUNTIF(\'Master Test Cases\'.M5:M{last_case_row};"Gagal")')
    set_formula(summary, 1, 16, f'=COUNTIF(\'Master Test Cases\'.M5:M{last_case_row};"Blocked")')
    set_formula(summary, 1, 17, f'=COUNTIF(\'Master Test Cases\'.M5:M{last_case_row};"Belum Diuji")')
    set_formula(summary, 1, 18, f'=COUNTIF(\'Master Test Cases\'.M5:M{last_case_row};"N/A")')
    set_formula(summary, 1, 19, "=IFERROR(B15/(B14-B19);0)")
    set_formula(summary, 1, 20, f'=COUNTIFS(\'Master Test Cases\'.E5:E{last_case_row};"Critical";\'Master Test Cases\'.M5:M{last_case_row};"Gagal")+COUNTIFS(\'Master Test Cases\'.E5:E{last_case_row};"High";\'Master Test Cases\'.M5:M{last_case_row};"Gagal")+COUNTIFS(\'Master Test Cases\'.E5:E{last_case_row};"Critical";\'Master Test Cases\'.M5:M{last_case_row};"Blocked")+COUNTIFS(\'Master Test Cases\'.E5:E{last_case_row};"High";\'Master Test Cases\'.M5:M{last_case_row};"Blocked")')
    set_widths(summary, [5000, 3600, 2200, 2200, 2200, 2200, 2200, 2200, 2200, 2200])
    freeze(summary, doc, 0, 3)

    master = add_sheet(doc, "Master Test Cases")
    merge_title(
        master,
        17,
        "MASTER TEST CASES — SEMUA FITUR SISTEM",
        "Status diisi melalui dropdown. Gunakan Actual Result, Evidence, dan Defect ID untuk setiap kegagalan/blocked.",
    )
    headers = [
        "No.", "Test Case ID", "Modul", "Submodul", "Prioritas", "Jenis Test", "Metode",
        "Precondition", "Test Data/Kondisi", "Langkah Pengujian", "Hasil yang Diharapkan",
        "Checklist Persiapan", "Status", "Actual Result", "Evidence/Log/Foto", "Defect ID",
        "Tester", "Tanggal Test",
    ]
    rows = [headers]
    for no, case in enumerate(cases, 1):
        test_id, module, submodule, priority, test_type, method, pre, data, steps, expected = case
        checklist = "☐ Precondition terpenuhi\n☐ Test data/device siap\n☐ Evidence disiapkan"
        rows.append([no, test_id, module, submodule, priority, test_type, method, pre, data, steps, expected, checklist, "Belum Diuji", "", "", "", "", ""])
    write_rows(master, 3, rows)
    style_table(master, 3, len(rows), len(headers))
    set_widths(master, [900, 1800, 2400, 2700, 1800, 2500, 1800, 4100, 3700, 6200, 6000, 3500, 2300, 5100, 3600, 1900, 2200, 2300])
    add_list_validation(master, f"E5:E{last_case_row}", "$Referensi.$B$2:$B$5", "prioritas")
    add_list_validation(master, f"G5:G{last_case_row}", "$Referensi.$C$2:$C$4", "metode")
    add_list_validation(master, f"M5:M{last_case_row}", "$Referensi.$A$2:$A$6", "status test")
    add_autofilter(doc, master, "MasterCasesTable", f"A4:R{last_case_row}")
    freeze(master, doc, 0, 4)

    usecases = add_sheet(doc, "Use Case E2E")
    merge_title(
        usecases,
        8,
        "END-TO-END USE CASES",
        "Gunakan untuk memvalidasi alur lintas modul, bukan hanya fungsi individual.",
    )
    usecase_headers = ["ID", "Use Case", "Aktor", "Precondition", "Trigger", "Main Flow", "Alternative/Exception Flow", "Acceptance Criteria", "Status"]
    usecase_rows = [usecase_headers]
    for row in e2e_use_cases():
        usecase_rows.append([*row, "Belum Diuji"])
    write_rows(usecases, 3, usecase_rows)
    style_table(usecases, 3, len(usecase_rows), len(usecase_headers))
    set_widths(usecases, [1500, 3300, 2200, 4100, 3200, 6700, 5700, 5500, 2300])
    add_list_validation(usecases, "I5:I19", "$Referensi.$A$2:$A$6", "status use case")
    add_autofilter(doc, usecases, "UseCaseTable", "A4:I19")
    freeze(usecases, doc, 0, 4)

    defects = add_sheet(doc, "Defect Log")
    merge_title(defects, 14, "DEFECT LOG DAN RETEST", "Satu defect dapat terkait lebih dari satu Test Case ID. Critical/High wajib selesai atau memiliki waiver tertulis sebelum release.")
    defect_headers = [
        "No.", "Defect ID", "Test Case ID", "Tanggal", "Modul", "Ringkasan", "Langkah Reproduksi",
        "Expected", "Actual", "Severity", "Priority", "PIC", "Status", "Target Fix", "Retest Result/Evidence",
    ]
    defect_rows = [defect_headers]
    for no in range(1, 41):
        defect_rows.append([no, f"DEF-{no:03d}", "", "", "", "", "", "", "", "", "", "", "Open", "", ""])
    write_rows(defects, 3, defect_rows)
    style_table(defects, 3, len(defect_rows), len(defect_headers))
    set_widths(defects, [900, 1700, 1900, 2200, 2300, 4600, 5700, 4600, 4600, 1900, 1800, 2200, 2300, 2300, 4500])
    add_list_validation(defects, "J5:J44", "$Referensi.$D$2:$D$5", "severity")
    add_list_validation(defects, "K5:K44", "$Referensi.$B$2:$B$5", "priority")
    add_list_validation(defects, "M5:M44", "$Referensi.$E$2:$E$7", "status defect")
    add_autofilter(doc, defects, "DefectTable", "A4:O44")
    freeze(defects, doc, 0, 4)

    environment = add_sheet(doc, "Environment & Device")
    merge_title(environment, 9, "TEST ENVIRONMENT & DEVICE MATRIX", "Catat versi dan identitas fisik agar hasil dapat direproduksi.")
    env_headers = ["No.", "Komponen", "Model/Identitas", "OS/Firmware", "Versi Software", "Koneksi/Port", "Konfigurasi Penting", "Status Kesiapan", "Bukti", "Catatan"]
    components = [
        "Jetson Orin Nano", "Head-unit display/touch", "Flutter SDK/build", "Backend Python", "Kamera DMS/Face ID",
        "ESP32 pothole", "BNO055/IMU", "GPS module", "ESP32 ambient light", "Smart fragrance controller",
        "Android phone 1", "Android phone 2", "iPhone", "USB cable", "USB storage/audio", "Bluetooth adapter",
        "Wi-Fi adapter", "RJ45 peer/Raspberry Pi", "MQTT broker", "Spotify account/device", "Audio sink/speaker",
    ]
    env_rows = [env_headers] + [[no, component, "", "", "", "", "", "Belum Siap", "", ""] for no, component in enumerate(components, 1)]
    write_rows(environment, 3, env_rows)
    style_table(environment, 3, len(env_rows), len(env_headers))
    set_widths(environment, [900, 3000, 3300, 3000, 3000, 2500, 4900, 2400, 3000, 4200])
    add_list_validation(environment, f"H5:H{4 + len(components)}", "$Referensi.$F$2:$F$5", "kesiapan")
    add_autofilter(doc, environment, "EnvironmentTable", f"A4:J{4 + len(components)}")
    freeze(environment, doc, 0, 4)

    release = add_sheet(doc, "Release Checklist")
    merge_title(release, 9, "RELEASE / CUSTOMER DEMO CHECKLIST", "Checklist ini melengkapi test case dan tidak menggantikan hasil manual perangkat nyata.")
    release_headers = ["No.", "Gate", "Perintah/Verifikasi", "Target", "Checklist", "Hasil Aktual", "Status", "Evidence", "PIC", "Tanggal"]
    gates = [
        ("Backend automated tests", "./scripts/test_backend_quality.sh", "100% pass; coverage critical ≥90%"),
        ("Flutter analyzer", "cd frontend && flutter analyze --no-pub", "0 issue"),
        ("Flutter automated tests", "cd frontend && flutter test --no-pub", "100% pass"),
        ("Android Auto TypeScript", "./scripts/build_android_auto_receiver.sh && npm test", "Build/type-check/test pass"),
        ("ESP32 pothole quality", "./scripts/test_pothole_quality.sh", "Native test/coverage/build firmware pass"),
        ("Linux ARM64 release build", "cd frontend && flutter build linux --release --no-pub", "Bundle berhasil"),
        ("Data produksi aman", "Bandingkan backend/dataset/profile sebelum-sesudah test otomatis", "Tidak berubah"),
        ("Manual Face ID", "FACE-007/008/015/016", "Target FAR/FRR disetujui"),
        ("Manual DMS/Mood", "DMS-004/005/011 dan MOOD-003", "Akurasi/false alarm target"),
        ("Manual ESP32/GPS/Pothole", "GPS-004/005, POT-005/009, MAP-005", "Seluruh hardware scenario pass"),
        ("Manual projection", "AA-001..007, AAW-001..003, CP-002", "Device in-scope pass/gap approved"),
        ("Manual fragrance/ambient", "FRAG-001..008, AMB-001..005", "Output fisik/fail-safe pass"),
        ("Performance/endurance", "NF-001..009 dan PROJ-003", "Target FPS/latency/RAM/suhu pass"),
        ("Security/privacy review", "SEC-001..003", "Risiko diterima/ditutup"),
        ("Defect gate", "Review Defect Log", "0 Critical/High open"),
        ("Customer sign-off", "Workbook Customer Acceptance", "Ditandatangani pihak terkait"),
    ]
    release_rows = [release_headers] + [[no, gate, verify, target, "☐", "", "Belum Diuji", "", "", ""] for no, (gate, verify, target) in enumerate(gates, 1)]
    write_rows(release, 3, release_rows)
    style_table(release, 3, len(release_rows), len(release_headers))
    set_widths(release, [900, 3400, 6200, 4700, 1500, 3900, 2300, 3300, 2200, 2200])
    add_list_validation(release, "G5:G20", "$Referensi.$A$2:$A$6", "status gate")
    freeze(release, doc, 0, 4)

    reference = add_sheet(doc, "Referensi")
    merge_title(reference, 7, "REFERENSI STATUS, PRIORITAS, DAN DEFINISI")
    ref_rows = [
        ["Status Test", "Priority", "Metode", "Severity", "Status Defect", "Kesiapan", "Definisi", "Aturan"],
        ["Belum Diuji", "Critical", "Automated", "Critical", "Open", "Belum Siap", "Belum dilakukan", "Critical/High gagal atau blocked menghalangi release"],
        ["Lulus", "High", "Manual", "High", "In Progress", "Siap", "Expected = Actual", "Lulus wajib punya evidence untuk hardware/AI/performance"],
        ["Gagal", "Medium", "Hybrid", "Medium", "Ready for Retest", "Siap dengan Catatan", "Expected tidak terpenuhi", "Isi Actual Result dan Defect ID"],
        ["Blocked", "Low", "", "Low", "Retest", "N/A", "Tidak dapat diuji karena blocker", "Catat blocker, owner, dan target"],
        ["N/A", "", "", "", "Closed", "", "Di luar scope", "N/A wajib memiliki alasan/waiver"],
        ["", "", "", "", "Deferred", "", "Ditunda dengan persetujuan", "Tidak boleh menyembunyikan defect Critical"],
    ]
    write_rows(reference, 2, ref_rows)
    style_table(reference, 2, len(ref_rows), len(ref_rows[0]))
    set_widths(reference, [2400, 1900, 1900, 1900, 2500, 3000, 4300, 6000])

    doc.Sheets.moveByName("Ringkasan", 0)
    doc.CurrentController.setActiveSheet(summary)
    store_xlsx(doc, output)
    doc.close(True)


def connect_office():
    PROFILE.mkdir(parents=True, exist_ok=True)
    command = [
        "/usr/bin/soffice",
        "--headless",
        "--nologo",
        "--nodefault",
        "--nofirststartwizard",
        "--norestore",
        f"-env:UserInstallation={uno.systemPathToFileUrl(str(PROFILE))}",
        f"--accept=pipe,name={PIPE_NAME};urp;StarOffice.ComponentContext",
    ]
    process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    local_context = uno.getComponentContext()
    resolver = local_context.ServiceManager.createInstanceWithContext(
        "com.sun.star.bridge.UnoUrlResolver", local_context
    )
    deadline = time.time() + 20
    while time.time() < deadline:
        try:
            context = resolver.resolve(
                f"uno:pipe,name={PIPE_NAME};urp;StarOffice.ComponentContext"
            )
            desktop = context.ServiceManager.createInstanceWithContext(
                "com.sun.star.frame.Desktop", context
            )
            return process, desktop
        except Exception:
            time.sleep(0.25)
    process.terminate()
    raise RuntimeError("Tidak dapat terhubung ke LibreOffice headless")


def verify_workbook(desktop, path: Path, expected_sheets: list[str]) -> None:
    doc = desktop.loadComponentFromURL(
        uno.systemPathToFileUrl(str(path)),
        "_blank",
        0,
        (prop("Hidden", True), prop("ReadOnly", True)),
    )
    actual = [doc.Sheets.getByIndex(i).Name for i in range(doc.Sheets.getCount())]
    doc.close(True)
    if actual != expected_sheets:
        raise RuntimeError(f"Sheet mismatch for {path.name}: {actual}")
    if path.stat().st_size < 20_000:
        raise RuntimeError(f"Workbook terlalu kecil/tidak lengkap: {path}")
    print(f"OK {path.name}: {len(actual)} sheets, {path.stat().st_size:,} bytes")


def main() -> None:
    acceptance_path = ROOT / "01_Customer_Acceptance_Multimedia_Project.xlsx"
    system_path = ROOT / "02_System_Test_Cases_Multimedia_Project.xlsx"
    process, desktop = connect_office()
    try:
        build_acceptance_workbook(desktop, acceptance_path)
        build_system_workbook(desktop, system_path)
        verify_workbook(
            desktop,
            acceptance_path,
            ["Petunjuk & Identitas", "Customer Acceptance", "Feedback Customer", "Sign-Off", "Referensi"],
        )
        verify_workbook(
            desktop,
            system_path,
            ["Ringkasan", "Master Test Cases", "Use Case E2E", "Defect Log", "Environment & Device", "Release Checklist", "Referensi"],
        )
    finally:
        try:
            desktop.terminate()
        except Exception:
            pass
        process.wait(timeout=10)


if __name__ == "__main__":
    main()
