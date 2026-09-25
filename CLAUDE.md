# catat. — Aplikasi Android (Flutter)

Aplikasi pencatat pengeluaran dari gaji bulanan untuk Gen Z. UI **wajib mengikuti desain** di [`design/`](design/).

## Aturan UI (penting)
- **Sumber kebenaran:** [`design/DESIGN.md`](design/DESIGN.md), [`design/tokens.json`](design/tokens.json), dan PNG di [`design/screens/`](design/screens/).
- Sebelum membangun atau mengubah layar, **buka PNG layar itu** dan cocokkan: warna, ukuran huruf, radius, jarak, dan urutan elemen.
- Jangan hardcode warna atau ukuran di widget. Semua lewat theme/tokens di `lib/core/theme/`.
- Pakai komponen bersama di `lib/core/widgets/` (kartu kantong, tombol, top bar, bottom nav, chip, toggle). Jangan duplikasi.
- Jangan menambah info atau elemen yang tidak ada di desain. Prinsipnya **simpel untuk Gen Z**.
- Teks UI memakai Bahasa Indonesia santai, persis seperti di desain.
- Nama kantong **bisa diganti user**. Jangan hardcode "Wajib/Darurat/Keinginan" di logika, pakai `tipe` + nama dari data.

## Arsitektur & roadmap
Ikuti [`docs/ROADMAP.md`](docs/ROADMAP.md): local-first (drift/SQLite) + sync ke Supabase, Riverpod, logika uang di `domain/` dengan unit test, UI hanya lewat repository. Kerjakan per fase (F1 → F9). Uang disimpan sebagai integer rupiah.

## Stack
Flutter · go_router · flutter_riverpod · drift · supabase_flutter · google_mlkit_text_recognition · table_calendar · fl_chart · pdf/excel. Detail di DESIGN.md §6 dan docs/ROADMAP.md §1.

## Verifikasi
Jalankan di HP Android (`flutter run`), lalu bandingkan layar dengan PNG desain sebelum menganggap selesai.
