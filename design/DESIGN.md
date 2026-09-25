# catat. — Spesifikasi Desain (Sumber Kebenaran UI)

Aplikasi pencatat pengeluaran dari gaji bulanan untuk **Gen Z** (Android dulu, iOS menyusul).
Desain asli: Figma → https://www.figma.com/design/IjpLTFXrjTsBF7O8IBR0Is (halaman **"Prototoype - Catat."**).
Gambar tiap layar ada di [`screens/`](screens/) — **selalu bandingkan hasil build dengan PNG-nya.**

Semua angka di dokumen ini diambil langsung dari skrip yang membangun desain Figma, jadi nilainya persis.

---

## 1. Prinsip

1. **Simpel, sedikit info per layar.** Satu angka besar + maksimal 3–4 blok. Jangan tambah info yang tidak ada di desain.
2. **Aksi utama = Scan struk.** Selalu 1 tap dari mana saja (tombol tengah bottom nav + banner lime di Beranda).
3. **Bahasa santai Gen Z**, tetap jelas: "Sisa duitmu bulan ini", "Pas-in struk di dalam kotak", "Hemat parah". Hindari istilah akuntansi.
4. **3 kantong** = inti konsep. Warna kantong konsisten di semua layar (ikon, progress, titik kalender, chart).

---

## 2. Design Tokens

Versi mesin-baca: [`tokens.json`](tokens.json).

### Warna dasar
| Token | Hex | Pakai untuk |
|---|---|---|
| `ink` | `#0E0E10` | Teks utama, tombol primer, kartu hero gelap, bg layar gelap (Splash, Scan) |
| `lime` | `#D4FF4F` | Aksen brand: ikon di tombol gelap, pill "On track", banner Scan, layar sukses |
| `bg` | `#F6F6F1` | Background layar (off-white hangat) |
| `card` | `#FFFFFF` | Kartu / list / input |
| `muted` | `#71717A` | Teks sekunder |
| `faint` | `#A1A1AA` | Teks tersier, ikon tab non-aktif, label di atas bg gelap |
| `line` | `#E7E7E1` | Border & divider |
| `darkSurface` | `#26262A` | Tombol/permukaan di atas bg `ink` |
| `track` | `#F0F0EA` | Track progress bar |
| `danger` | `#E5484D` | Hapus, error, alokasi berlebih |
| `success` | `#12A36B` | Sukses (Laporan siap, struk kebaca) |

### Warna kantong (default)
| Tipe | Nama default | Warna | Soft bg | Ikon (Lucide) |
|---|---|---|---|---|
| `wajib` | Wajib | `#6D5DFC` | `#EEEBFF` | `home` |
| `darurat` | Darurat | `#12A36B` | `#E2F6EC` | `shield` |
| `keinginan` | Keinginan | `#FF4F7B` | `#FFE8EE` | `sparkles` |

Palet warna yang bisa dipilih user saat kustomisasi: `#6D5DFC` `#12A36B` `#FF4F7B` `#FF8A00` `#0EA5E9` `#EAB308` `#0E0E10`.
Soft bg = warna yang sama pada opacity ±12% di atas putih.

### Tipografi — **Plus Jakarta Sans** (Google Fonts)
| Peran | Size | Weight | Letter spacing |
|---|---|---|---|
| Angka hero (saldo, nominal) | 34–44 | ExtraBold 800 | -3% |
| Judul layar ("Catatan", "Laporan") | 26 | ExtraBold 800 | -3% |
| Headline onboarding | 34 (line-height 112%) | ExtraBold 800 | -3% |
| Judul section / top bar | 17 | ExtraBold 800 / Bold 700 (top bar) | -1% |
| Judul item (nama kantong, transaksi) | 15 | ExtraBold 800 | 0 |
| Body | 14–15 | Medium 500 / Bold 700 | 0 |
| Caption / sub | 12–13 | Medium 500 | 0 |
| Label tab & chip kecil | 11 | ExtraBold (aktif) / Medium | 0 |

### Radius
| Elemen | Radius |
|---|---|
| Kartu hero (saldo, ringkasan) | 28 (24 untuk ringkasan alokasi) |
| Kartu / list / banner | 20–22 |
| Tombol besar | 18 |
| Input, tile kecil, segmented | 14–16 |
| Chip / pill | 999 (penuh) |
| Badge ikon | lingkaran penuh, atau kotak `size × 0.32` |

### Spacing & layout
- Frame desain: **390 × 844** (logical px). Padding samping layar **20**.
- Jarak antar blok di layar: **20** (layar padat: 14–16).
- Padding kartu: **14–16** (hero: 20–22). List row: vertikal **11–12**.
- Status bar tinggi ±44, konten mulai 8px di bawahnya.
- Bottom nav: tinggi **100**, putih, border atas 1px `line`, padding `8/24/22/24`.

### Shadow
- Kartu mengambang: `0 8 20 rgba(14,14,16,.08)`
- FAB Scan: `0 6 14 rgba(14,14,16,.25)`
- Garis scan lime: glow `0 0 14 spread 2 rgba(212,255,79,.9)`

### Ikon
Gaya **Lucide** (stroke 2, rounded). Flutter: package `lucide_icons_flutter` (atau `lucide_icons`).

---

## 3. Komponen

| Komponen | Spesifikasi |
|---|---|
| **Badge ikon** | Lingkaran 36–44 (fill soft bg), ikon 46% ukuran, warna kantong |
| **Kartu kantong** | Row: badge 44 + [nama 15/800 + "Sisa Rp 450rb" 13/700 muted, rata kanan] + progress 8px warna kantong di track `#F0F0EA`. Kartu putih r20 p14 |
| **Kartu hero saldo** | Bg `ink` r28 p22: label 14 faint → angka 38/800 putih → baris "dari gaji …" + pill lime "On track" |
| **Banner Scan** | Bg `lime` r22 p16/18: badge 44 `ink` ikon scan lime + "Scan struk" 16/800 + sub 13 `#4A5A12` + chevron |
| **Tombol primer** | Bg `ink`, teks putih 16/700, r18, tinggi ±56 (pad 18), full width |
| **Tombol sekunder** | Bg putih, border `line`, teks `ink` |
| **Tombol disabled** | Bg `#DADAD4`, teks `muted` |
| **Top bar** | [tombol bulat 40 putih border `line` ikon back/x] — judul 17/700 tengah — [aksi 40 atau spacer 40] |
| **Bottom nav** | 5 slot: Beranda · Catatan · **Scan (FAB 54 ink, ikon lime, label "Scan")** · Laporan · Akun. Aktif = `ink` + label ExtraBold; non-aktif = `faint` |
| **Segmented** | Bg `#E7E7E1` r14 p4; item aktif putih r10 teks 13/800 |
| **Chip** | Pill; aktif = fill `ink`/warna kantong + teks putih; non-aktif = putih + border `line` |
| **Toggle** | 48×28 r14; ON = track `ink` + knob lime 22; OFF = track `#DADAD4` + knob putih |
| **Radio** | 22 lingkaran; ON = fill `ink` + titik lime 8; OFF = border 2 `#C9C9C2` |
| **Progress** | Track `#F0F0EA` tinggi 8–10 r penuh, isi warna kantong |
| **Loading step** | Row: [✓ badge 24 ink/lime \| spinner arc 24] + teks 15/700 |
| **Empty state** | Kartu putih r20 p24 center: badge 56 lime + judul 16/800 + sub 13 muted + pill "Tambah catatan" |
| **Bottom sheet** | Putih, radius atas 28, handle 40×5, overlay `ink` 55% |

Format uang: `Rp 6.500.000` (titik ribuan). Versi singkat di tempat sempit: `Rp 450rb`, `Rp 1,95jt`. Pengeluaran diawali `-`, pemasukan `+`.

---

## 4. Daftar Layar

File PNG: `screens/NN-nama.png` (lihat [`screens/README.md`](screens/README.md)).

### Alur utama
| # | Layar | Isi kunci | Navigasi |
|---|---|---|---|
| 00 | Splash | Bg ink, logo lime 96 r(sq), "catat." 44, tagline, loading dots | auto 1,5 dtk → 01 |
| 01 | Masuk / Daftar | Headline "Gajian aman, catat tanpa ribet.", ilustrasi *Gajian masuk → 3 kantong*, tombol Google + Email | → 02 |
| 02 | Atur Gaji | Gaji bersih, upload slip (dashed), tanggal gajian, toggle "Tambah otomatis", bar pembagian 3 kantong | Upload → 08 · Ubah → 20 · Simpan → 19 |
| 03 | Beranda | Header avatar, hero "Sisa duitmu", banner Scan, 3 kartu kantong, bottom nav | Scan → 04 · kartu Wajib → 12 · kartu Keinginan → 24 · Atur → 20 · lonceng → 18 |
| 04 | Scan Struk | Bg ink, viewfinder + bracket lime + garis scan, hint, Galeri / Shutter / Manual | Shutter/Galeri → 09 · Manual → 11 |
| 05 | Hasil Scan | Banner sukses, kartu struk (merchant, item, total), pilih kantong (tebakan AI), Simpan | Simpan → 10 · Scan ulang → 04 |
| 06 | Catatan Harian | Kalender bulan (titik warna kantong per hari, tgl gajian lime), daftar pengeluaran tanggal terpilih | item → 13 · tgl kosong → 26 |
| 07 | Export Laporan | Periode (Bulanan / 3 Bulan / Setahun), format (PDF / Excel), Download | → 15 |

### Loading, detail & pendukung
| # | Layar | Isi kunci |
|---|---|---|
| 08 | Loading baca slip gaji | Mock slip + highlight "Gaji bersih", progress, 3 langkah |
| 09 | Loading proses struk | Bg ink, struk + garis scan, progress lime, 3 langkah → auto ke 05 |
| 10 | Berhasil tercatat | Bg lime + confetti, check 96, "Tercatat!", kartu kantong terupdate, Ke beranda / Scan lagi |
| 11 | Catat manual | Nominal besar + caret, "Buat apa?", tanggal, chip kantong, keypad 4×3, Simpan → 10 |
| 12 | Detail kantong | Hero warna kantong (sisa, terpakai, progress), tips, riwayat per kantong |
| 13 | Detail transaksi | Ikon + nominal besar, pill kantong, info (tanggal, jam, sumber), isi struk, foto struk, Hapus |
| 14 | Laporan | Ringkasan bulan (keluar, gaji, sisa), progress per kantong, insight, Export → 07 |
| 15 | Loading siapin laporan | Mock dokumen + mini chart, 3 langkah → auto ke 16 |
| 16 | Laporan siap | Check hijau, kartu file PDF, Buka file / Bagikan |
| 17 | Akun | Profil, Keuangan (Gaji & slip, Atur kantong, Export), Aplikasi (Pengingat, Keamanan), Keluar |
| 18 | Gajian masuk (otomatis) | Bg ink + confetti, "+Rp 6.500.000", pembagian ke 3 kantong, "Mantap, lanjut" |

### Kustomisasi kantong & detail lainnya
| # | Layar | Isi kunci |
|---|---|---|
| 19 | Pilih template | Klasik 50/20/30 (Populer), Anak Kos 60/15/25, Pejuang Nabung 45/35/20, Bikin sendiri |
| 20 | Atur kantong | Ringkasan "100% teralokasi", mode Persen/Nominal, daftar kantong (drag handle, % pill), tips |
| 21 | Edit kantong | Preview, input nama (maks 20 karakter), 8 ikon, 7 warna, baris Jatah & rentang |
| 22 | Atur jatah & rentang | Nominal besar, slider %, chip cepat, **rentang min–maks**, aturan (ingetin < 20%, sisa → Dana Darurat) |
| 23 | Alokasi kelebihan | State error: 110%, kartu merah, "Rapiin otomatis", tombol Simpan disabled |
| 24 | Kantong hampir habis | Bottom sheet di atas Beranda: tinggal 15%, Pindahin / Oke siap hemat |
| 25 | Pindahin saldo | Dari → Ke (kantong), nominal, chip cepat, peringatan dana darurat |
| 26 | Catatan kosong | Empty state "Nggak ada jajan hari ini!" |

---

## 5. Model data (acuan)

```
User { id, nama, email, avatar }
Gaji { userId, nominalBersih, tanggalGajian (1–31), autoTambah: bool, slipUrl? }
Kantong {
  id, userId, tipe: wajib|darurat|keinginan,   // tipe tetap, dipakai laporan
  nama (≤20), ikon, warna, urutan,
  mode: persen|nominal, persen?, nominal?,
  rentangMin?, rentangMaks?,
  ingetinDiBawahPersen? (default 20), sisaKeDarurat: bool
}
Periode { userId, bulan (YYYY-MM), gaji, dibuatOtomatis: bool }
Transaksi {
  id, userId, kantongId, nominal, judul, tanggal, jam,
  sumber: scan|manual, merchant?, fotoStrukUrl?,
  items?: [{ nama, qty, harga }]
}
PindahSaldo { id, userId, dariKantongId, keKantongId, nominal, tanggal }
```
Aturan: total alokasi kantong **harus = 100%** (atau = gaji jika mode nominal) sebelum bisa disimpan (layar 23).

---

## 6. Rekomendasi implementasi Flutter

| Kebutuhan | Package |
|---|---|
| Font | `google_fonts` (Plus Jakarta Sans) |
| Ikon | `lucide_icons_flutter` |
| Navigasi | `go_router` (shell route untuk bottom nav) |
| State | `flutter_riverpod` |
| Backend / akun | `supabase_flutter` (Auth Google + email, Postgres, Storage untuk foto struk & slip) |
| Kamera & galeri | `camera`, `image_picker` |
| OCR struk & slip | `google_mlkit_text_recognition` (on-device, gratis) |
| Kalender | `table_calendar` |
| Chart | `fl_chart` |
| Export | `pdf` + `printing` (PDF), `excel` (XLSX), `share_plus` |
| Notifikasi pengingat | `flutter_local_notifications` |
| Format uang/tanggal | `intl` (locale `id_ID`) |

Struktur fitur yang disarankan: `lib/core/theme/` (tokens), `lib/core/widgets/` (komponen §3), `lib/features/<fitur>/` (layar §4).
