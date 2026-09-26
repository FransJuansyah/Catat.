# catat. — Arsitektur & Roadmap Menuju Play Store

Target: aplikasi pencatat pengeluaran dari gaji yang **benar-benar dipakai sehari-hari** oleh Gen Z, stabil, aman, dan lolos review Google Play.
Prinsip biaya: **semua komponen memakai paket gratis.** Satu-satunya biaya wajib adalah akun Google Play Developer (USD 25, sekali bayar).

---

## 1. Keputusan arsitektur

| Area | Keputusan | Alasan |
|---|---|---|
| App | **Flutter** (Android dulu, iOS menyusul) | Sudah berjalan, UI sesuai desain |
| Data di HP | **Local-first: SQLite via `drift`** sebagai sumber data utama di perangkat | Nyatat harus instan & jalan tanpa sinyal (di kasir, di jalan). Menambah offline belakangan jauh lebih mahal |
| Backend | **Supabase** (Auth, Postgres, Storage) | Paket gratis, SQL beneran, Row Level Security, gampang di-scale |
| Sinkronisasi | Antrian perubahan lokal (outbox) → push ke Supabase saat online; pull perubahan berdasar `updated_at` | Multi-HP & backup tanpa kehilangan data |
| Login | Google Sign-In + Email (Supabase Auth) | Sesuai desain layar 01 |
| State | **Riverpod** | Terstruktur, mudah dites |
| OCR struk & slip | **Google ML Kit Text Recognition** (on-device) + parser aturan untuk struk Indonesia | Gratis, cepat, privasi (foto tidak wajib keluar HP) |
| Tebak kantong | Aturan kata kunci + belajar dari koreksi user (disimpan lokal) | Gratis, makin pintar dipakai |
| Gaji otomatis tiap bulan | Dibuat **di HP saat app dibuka** setelah tanggal gajian (idempoten), + notifikasi lokal di hari gajian | Tidak butuh server/cron, jalan offline |
| Laporan & export | Dibuat **di HP**: `pdf`/`printing` (PDF), `excel` (XLSX), dibagikan via `share_plus` | Gratis, tanpa server |
| Keamanan | RLS di Supabase, PIN/biometrik (`local_auth`), token di `flutter_secure_storage` | Data keuangan = sensitif |
| Crash & error | Firebase Crashlytics (gratis) | Tahu error di HP user sebelum mereka komplain |
| Uang | Disimpan sebagai **integer rupiah** (bukan double) | Hindari error pembulatan |

### Lapisan kode
```
lib/
├── core/            theme, widgets bersama, format, error, utils
├── data/
│   ├── local/       drift database, DAO, tabel
│   ├── remote/      supabase client & API
│   ├── sync/        outbox + pull/push
│   └── repositories/  satu pintu akses data (dipakai UI)
├── domain/          model & logika murni (hitung sisa kantong, periode gaji, validasi alokasi, parser struk)
└── features/<fitur>/  layar + controller Riverpod
```
Aturan: UI **tidak** boleh akses database/Supabase langsung, selalu lewat repository. Logika uang di `domain/` dan **wajib ada unit test**.

---

## 2. Model data (Postgres + SQLite, struktur sama)

Semua tabel: `id uuid`, `user_id`, `created_at`, `updated_at`, `deleted_at` (soft delete untuk sync).

| Tabel | Kolom penting |
|---|---|
| `profiles` | nama, avatar, zona waktu, pin_aktif |
| `salary_settings` | nominal_bersih, tanggal_gajian (1–31, jika bulan pendek → hari terakhir), auto_tambah, slip_path |
| `pockets` | tipe (`wajib`/`darurat`/`keinginan`), nama (≤20), ikon, warna, urutan, mode (`persen`/`nominal`), persen, nominal, rentang_min, rentang_maks, ingetin_di_bawah_persen, sisa_ke_darurat |
| `periods` | bulan (YYYY-MM), mulai, selesai, gaji, dibuat_otomatis |
| `period_allocations` | period_id, pocket_id, jatah (snapshot jatah saat periode dibuat) |
| `expenses` | pocket_id, period_id, nominal, judul, tanggal, jam, sumber (`scan`/`manual`), merchant, foto_path, catatan |
| `expense_items` | expense_id, nama, qty, harga |
| `transfers` | dari_pocket_id, ke_pocket_id, nominal, period_id |
| `category_hints` | kata_kunci → pocket_tipe (belajar dari koreksi user) |

Aturan bisnis inti (di `domain/`, dites):
- Total alokasi = 100% (atau = gaji jika mode nominal). Jatah dijepit ke `rentang_min..rentang_maks`.
- Sisa kantong = jatah periode + transfer masuk − transfer keluar − pengeluaran.
- Periode baru dibuat sekali per siklus gajian (idempoten, aman walau app dibuka berkali-kali / offline).
- Sisa akhir periode → Dana Darurat jika aturan aktif.
- Peringatan saat sisa < ambang (default 20%).

---

## 3. Roadmap per fase

Setiap fase selesai = **bisa dipakai di HP**, dites, dan dicocokkan dengan PNG di `design/screens/`.

| Fase | Isi | Layar desain | Selesai jika |
|---|---|---|---|
| **F0 Fondasi** ✅ sebagian | Theme & komponen, navigasi, Beranda | 03 | ✅ sudah jalan di HP |
| **F1 Fondasi data** ✅ | drift DB + migrasi, repository, Riverpod, domain + unit test, ganti DemoData | – | Beranda baca dari DB lokal |
| **F2 Pencatatan inti** ✅ | Catat manual, detail & hapus transaksi, detail kantong, Catatan harian (kalender), empty state | 06, 11, 12, 13, 26 | Bisa pakai harian tanpa internet |
| **F3 Onboarding & multi pemasukan** ✅ | Splash & ikon, pilih sumber uang (gaji bulanan / uang jajan harian-mingguan-bulanan / penghasilan tidak tetap), setup per mode, pilih template, periode otomatis, layar Gajian masuk, tambah pemasukan yang langsung dibagi ke kantong, pemasukan di Catatan | 00, 01, 02, 18, 19, 27–31 | Gajian/uang jajan otomatis masuk; pemasukan bebas langsung kebagi |
| **F4 Kustomisasi kantong** | Atur/edit kantong (nama, ikon, warna), jatah & rentang, validasi 100%, pindah saldo, peringatan hampir habis | 20–25 | Semua aturan kantong jalan & dites |
| **F5 Scan struk** | Kamera, ML Kit, parser struk Indonesia (Indomaret, Alfamart, resto, e-wallet), tebak kantong, konfirmasi, simpan foto | 04, 05, 09, 10 | ≥80% struk umum terbaca benar totalnya |
| **F6 Slip gaji** | Upload foto/PDF slip → baca nominal gaji bersih | 02, 08 | Nominal terisi otomatis, bisa dikoreksi |
| **F7 Laporan & export** | Laporan bulanan, insight, export PDF/Excel bulanan / 3 bulan / setahun | 07, 14, 15, 16 | File terbuka rapi di HP & laptop |
| **F8 Akun & sinkron** | Login Google/Email, sync ke Supabase, multi-HP, hapus akun & data, PIN/biometrik, pengingat harian | 01, 17 | Ganti HP → data kembali utuh |
| **F9 Siap rilis** | Ikon & nama app ✅, font dibundel ✅, keystore, Crashlytics, kebijakan privasi, Data Safety form, uji tertutup | – | Lolos review & tayang di Play Store |

---

## 4. Checklist Play Store (F9)

- [ ] Akun Google Play Developer (USD 25, sekali bayar)
- [ ] Keystore upload sendiri; **backup di 2 tempat aman** (hilang = tidak bisa update app)
- [ ] `applicationId` final (saat ini `id.catat.catat`, ganti sebelum rilis pertama; tidak bisa diubah setelahnya)
- [ ] Ikon adaptif, nama app, screenshot store, deskripsi, feature graphic
- [ ] **Kebijakan privasi** (bisa di-host gratis, mis. GitHub Pages), menjelaskan kamera, foto struk, data keuangan
- [ ] Form **Data Safety**: data apa dikumpulkan, dienkripsi saat transit, user bisa minta hapus
- [ ] Fitur **hapus akun & data** dari dalam app (wajib Play Store)
- [ ] Target API level sesuai syarat Google terbaru
- [ ] Akun developer pribadi baru: **uji tertutup** dengan sejumlah penguji selama periode tertentu sebelum rilis produksi (cek syarat terbaru di Play Console)
- [ ] Build: `flutter build appbundle --release`

---

## 5. Aturan kerja

1. Satu fase = satu branch git → merge ke `main` setelah lolos: `flutter analyze` bersih, test hijau, dicek di HP.
2. Logika uang & tanggal selalu punya unit test (kasus: tanggal gajian 31 di Februari, alokasi ≠ 100%, transfer, rollover).
3. Jangan simpan kunci rahasia di kode. `SUPABASE_URL` / `ANON_KEY` lewat `--dart-define` / file env yang di-`.gitignore`.
4. Setiap perubahan skema DB = migrasi drift + migrasi SQL Supabase.
