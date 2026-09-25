# catat.

Aplikasi Android (Flutter) untuk mencatat pengeluaran dari gaji bulanan, dibuat untuk Gen Z. Gaji otomatis terbagi ke 3 kantong yang bisa dikustom (Wajib, Darurat, Keinginan), dan pengeluaran dicatat cukup dengan scan struk.

## Fitur (target)
- **Scan struk:** hasilnya langsung tercatat dan kantongnya ditebak otomatis (OCR on-device)
- **Slip gaji:** saldo otomatis bertambah setiap tanggal gajian
- **3 kantong kustom:** nama, ikon, warna, jatah, dan rentang bisa diatur sendiri
- **Catatan harian** berbasis kalender
- **Laporan** yang bisa di-export ke PDF atau Excel (bulanan, 3 bulan, atau setahun)
- **Local-first:** tetap jalan tanpa internet, lalu sinkron ke cloud

## Dokumen
- [`docs/ROADMAP.md`](docs/ROADMAP.md): arsitektur, model data, dan fase pengembangan sampai rilis di Play Store
- [`design/DESIGN.md`](design/DESIGN.md): spesifikasi UI dan token desain. Gambar tiap layar ada di [`design/screens/`](design/screens/)
- [`CLAUDE.md`](CLAUDE.md): aturan pengembangan

## Menjalankan
```bash
flutter pub get
flutter run            # ke HP Android yang tersambung (USB debugging aktif)
flutter test
flutter analyze
```

Butuh Flutter versi stable (3.47+) dan Android SDK.
