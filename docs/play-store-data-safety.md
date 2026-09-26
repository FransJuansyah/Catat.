# Isian Play Console: Data Safety, izin & listing

Contekan saat mengisi Play Console untuk **rilis pertama (tanpa akun/sinkron, F8 belum ada)**. Wajib diperbarui saat F8 (login Google + Supabase) dirilis.

## 1. Data Safety

Menurut Google, data yang **hanya diproses di HP dan tidak dikirim keluar** tidak dihitung sebagai "dikumpulkan". Semua catatan catat. saat ini tersimpan di HP.

| Pertanyaan | Jawaban |
|---|---|
| Apakah app mengumpulkan atau membagikan data pengguna yang wajib dilaporkan? | **Lihat catatan ML Kit di bawah.** Tanpa ML Kit jawabannya "Tidak". |
| Apakah data dienkripsi saat transit? | Ya (ML Kit memakai HTTPS). Tidak ada server catat. |
| Bisakah pengguna meminta data dihapus? | Ya: hapus data aplikasi / uninstall (semua data ada di HP). |

**Catatan ML Kit (wajib dicek sebelum submit):** Google ML Kit (pembaca teks struk & slip) dapat mengirim data diagnostik dan info perangkat ke Google. Google menerbitkan daftar jawaban Data Safety untuk ML Kit di halaman *"ML Kit Android data disclosure"* (developers.google.com/ml-kit). Salin kategori dari sana (biasanya **Info & performa aplikasi** dan **ID perangkat atau ID lain**, tujuan: analitik/fungsi app, tidak dibagikan, tidak bisa dimatikan pengguna). Isi teks struk/slip **tidak** dikirim.

**Tidak** dilaporkan sebagai dikumpulkan (hanya di HP): info keuangan, foto struk, isi notifikasi/SMS/email, nama panggilan.

## 2. Izin sensitif & deklarasi

| Izin / fitur | Deklarasi Play | Catatan |
|---|---|---|
| `BIND_NOTIFICATION_LISTENER_SERVICE` (catat otomatis) | Tidak ada formulir khusus, tapi wajib patuh **User Data policy**: pengungkapan jelas di dalam app sebelum izin diminta. | Sudah ada: layar Privasi & izin (35/37) + sheet ⓘ (36), dan semua item mati dari awal. Siapkan video singkat alur ini kalau reviewer meminta. |
| `CAMERA` | Tidak perlu deklarasi. | Hanya saat scan struk. |
| `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` | Tidak perlu deklarasi. | Tercatat + pengingat 21:00. |
| SMS (`READ_SMS`) | **Tidak dipakai.** | SMS bank dibaca dari notifikasinya, jadi tidak butuh izin SMS (yang formulirnya sangat ketat). |

## 3. Target & format

- `targetSdk` = 36 (Android 16), `minSdk` = 24 (Android 7.0).
- Unggah **AAB**: `flutter build appbundle --release`. Unduhan per HP kira-kira 20–25 MB (APK gemuk 3 arsitektur ±100 MB tidak dipakai untuk Play Store).

## 4. Sebelum rilis pertama (keputusan pemilik)

- [ ] **applicationId final.** Sekarang `id.catat.catat`. **Tidak bisa diganti** setelah rilis pertama. Pastikan tidak bentrok dengan app lain di Play Store.
- [ ] **Keystore upload.** Buat sekali, simpan `android/key.properties` + file `.jks`, **backup di 2 tempat aman**. Pakai *Play App Signing* supaya kunci upload yang hilang masih bisa di-reset.
- [ ] **Kebijakan privasi.** Isi placeholder di `docs/kebijakan-privasi.md` (nama, email, tanggal), lalu host misalnya lewat GitHub Pages dan tempel URL-nya di Play Console.
- [ ] **Kategori usia & konten.** Ada mode "Pelajar". Jika target audiens mencakup di bawah 13 tahun, berlaku **Families Policy** (lebih ketat). Sarankan target 13+.
- [ ] **Uji tertutup.** Akun developer pribadi baru wajib uji tertutup dengan sejumlah penguji selama periode tertentu (cek syarat terbaru di Play Console).
