import 'package:catat/domain/receipt_parser.dart';
import 'package:catat/domain/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 26, 10);

  group('nominal', () {
    test('format rupiah umum', () {
      expect(parseAmount('36.000'), 36000);
      expect(parseAmount('36,000'), 36000);
      expect(parseAmount('36.000,00'), 36000);
      expect(parseAmount('1.250.000'), 1250000);
      expect(parseAmount('52000'), 52000);
      expect(parseAmount('abc'), isNull);
    });

    test('tanggal, jam & angka kecil tidak dianggap harga', () {
      expect(amountsIn('24/09/26 10:15'), isEmpty);
      expect(amountsIn('SUSU UHT 1L x2  36.000'), [36000]);
      expect(amountsIn('Total Rp 52.000'), [52000]);
      expect(amountsIn('Rp.15.500,00'), [15500]);
    });
  });

  test('Indomaret (qty & harga satuan di satu baris)', () {
    final r = parseReceipt([
      'INDOMARET',
      'PT. INDOMARCO PRISMATAMA',
      'JL. SUDIRMAN 12 JAKARTA',
      'NPWP 01.337.994.6-092.000',
      '24.09.26-10:15  2.0.9  123456/KASIR/01',
      'SUSU UHT 1L  2  18,000  36,000',
      'ROTI TAWAR  1  16,000  16,000',
      'HARGA JUAL :  52,000',
      'TOTAL :  52,000',
      'TUNAI :  100,000',
      'KEMBALI :  48,000',
      'PPN :  4,727',
    ], now: now);
    expect(r.merchant, 'Indomaret');
    expect(r.total, 52000);
    expect(r.totalFromKeyword, isTrue);
    expect(r.date, DateTime(2026, 9, 24, 10, 15));
    expect(r.items.map((i) => (i.name, i.qty, i.price)), [
      ('Susu Uht 1L', 2, 36000),
      ('Roti Tawar', 1, 16000),
    ]);
    expect(r.confident, isTrue);
    expect(guessPocketType(r), PocketType.wajib);
  });

  test('Alfamart (qty × harga di baris bawah nama)', () {
    final r = parseReceipt([
      'ALFAMART',
      'JL RAYA BOGOR KM 30',
      'Tgl. 23-09-2026 19:42',
      'INDOMIE GORENG',
      '5 x 3.100  15.500',
      'AQUA 600ML',
      '1 x 3.500  3.500',
      'Total Item 6',
      'Total Belanja  19.000',
      'Tunai  20.000',
      'Kembalian  1.000',
    ], now: now);
    expect(r.merchant, 'Alfamart');
    expect(r.total, 19000);
    expect(r.date, DateTime(2026, 9, 23, 19, 42));
    expect(r.items.map((i) => (i.name, i.qty, i.price)), [
      ('Indomie Goreng', 5, 15500),
      ('Aqua 600ML', 1, 3500),
    ]);
    expect(r.confident, isTrue);
  });

  test('Kafe dengan pajak & service: total = grand total', () {
    final r = parseReceipt([
      'KOPI SENJA',
      'Jl. Kaliurang Km 5',
      '26 Sep 2026  08:30',
      'Es Kopi Susu  x2  44.000',
      'Croissant  28.000',
      'Subtotal  72.000',
      'Service 5%  3.600',
      'PB1 10%  7.560',
      'Grand Total  83.160',
      'Cash  100.000',
    ], now: now);
    expect(r.merchant, 'Kopi Senja');
    expect(r.total, 83160);
    expect(r.date, DateTime(2026, 9, 26, 8, 30));
    expect(r.items.map((i) => i.name), ['Es Kopi Susu', 'Croissant']);
    expect(r.items.first.qty, 2);
    expect(guessPocketType(r), PocketType.keinginan);
  });

  test('Bukti bayar e-wallet (tanpa item)', () {
    final r = parseReceipt([
      'Pembayaran Berhasil',
      'GoPay',
      'Apotek Sehat Selalu',
      '25 September 2026, 14:05',
      'Total Bayar',
      'Rp45.500',
      'ID Transaksi 889922110033',
    ], now: now);
    expect(r.merchant, 'Apotek Sehat Selalu');
    expect(r.total, 45500);
    expect(r.date, DateTime(2026, 9, 25, 14, 5));
    expect(guessPocketType(r), PocketType.darurat);
  });

  test('tanpa kata TOTAL → jumlah item / nominal terbesar', () {
    final r = parseReceipt([
      'WARUNG BU SRI',
      'Nasi Rames  15.000',
      'Es Teh  5.000',
    ], now: now);
    expect(r.total, 20000);
    expect(r.totalFromKeyword, isFalse);
    expect(r.confident, isFalse);
  });

  test('tanggal masa depan / terlalu lama diabaikan', () {
    expect(
      parseReceipt(['TOKO', '01/01/2030', 'TOTAL 5.000'], now: now).date,
      isNull,
    );
    expect(
      parseReceipt(['TOKO', '01/01/2020', 'TOTAL 5.000'], now: now).date,
      isNull,
    );
  });

  test('jam di baris tanggal menang dari jam lain (status bar screenshot)', () {
    final r = parseReceipt([
      '9:41',
      'INDOMARET',
      'Jl. Sudirman 12  24/09/26  10:15',
      'TOTAL  52.000',
    ], now: now);
    expect(r.date, DateTime(2026, 9, 24, 10, 15));
  });

  test('struk kosong / tidak kebaca', () {
    final r = parseReceipt(['   ', 'asdf'], now: now);
    expect(r.total, isNull);
    expect(r.items, isEmpty);
  });

  group('gabung baris OCR', () {
    test('nama & harga sejajar jadi satu baris', () {
      final rows = groupRows(const [
        OcrLine('INDOMARET', 40, 10, 300, 40),
        OcrLine('36.000', 400, 102, 480, 128),
        OcrLine('SUSU UHT 1L x2', 40, 100, 260, 126),
        OcrLine('ROTI TAWAR', 40, 140, 220, 166),
        OcrLine('16.000', 402, 143, 480, 168),
        OcrLine('TOTAL', 40, 190, 130, 220),
        OcrLine('52.000', 380, 188, 480, 222),
      ]);
      expect(rows, [
        'INDOMARET',
        'SUSU UHT 1L x2  36.000',
        'ROTI TAWAR  16.000',
        'TOTAL  52.000',
      ]);
      final r = parseReceipt(rows, now: now);
      expect(r.total, 52000);
      expect(r.itemsSum, 52000);
    });

    test('baris miring sedikit tetap tergabung', () {
      final rows = groupRows(const [
        OcrLine('TOTAL', 40, 200, 130, 230),
        OcrLine('52.000', 380, 210, 480, 240),
      ]);
      expect(rows, ['TOTAL  52.000']);
    });
  });
}
