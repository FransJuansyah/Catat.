# Korpus struk untuk uji akurasi scan

`korpus.json` berisi **hasil OCR asli ML Kit dari HP** (teks per baris + posisinya) untuk 222 foto struk Indonesia, beserta kunci jawabannya. Fotonya sendiri tidak disimpan di repo.

| Sumber | Jumlah | Lisensi | Kunci jawaban |
|---|---|---|---|
| [CORD v2](https://github.com/clovaai/cord) (NAVER Clova): struk restoran, kafe & toko di Indonesia (test, validation, 26 train) | 219 | CC BY 4.0 | `gt_parse.total.total_price` |
| Wikimedia Commons: struk Lawson QRIS & mesin EDC BCA (VulcanSphere), nota taksi Yogyakarta (Sasha India) | 3 | CC BY 4.0 / CC BY 2.0 | dibaca manual (`tool/struk_web.json`) |

CORD mengaburkan nama toko & tanggal, jadi struk CORD hanya dipakai untuk menguji total.

## Memperbarui

1. `node tool/unduh_cord.js test 100` (atau `validation` / `train`): foto ke `tool/struk_korpus/` (tidak di-commit).
2. Salin foto ke app uji, lalu jalankan `CATAT_UJI=1 flutter run -t tool/ocr_dump.dart` di HP. Hasil OCR ditarik dari `app_flutter/korpus_out/` ke `tool/struk_korpus/korpus_out/`.
3. `node tool/buat_fixture_struk.js` membuat ulang `korpus.json`.
4. `dart run tool/uji_korpus.dart` menampilkan akurasi dan daftar yang meleset. Tambahkan id struk untuk melihat baris OCR-nya.

Test regresi: `test/domain/receipt_corpus_test.dart`.
