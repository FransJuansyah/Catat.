import 'package:catat/domain/receipt_lock.dart';
import 'package:catat/domain/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scan otomatis (layar 04 → 46).
void main() {
  ReceiptData frame(List<String> rows) =>
      parseReceipt(rows, now: DateTime(2026, 9, 27, 10));

  const struk = [
    'INDOMARET',
    'SUSU UHT 1L x2  36.000',
    'ROTI TAWAR  16.000',
    'TOTAL  52.000',
  ];

  test('TOTAL sama di 2 frame berturut-turut → kebaca', () {
    final lock = ReceiptLock();
    expect(lock.add(frame(struk)), isFalse);
    expect(lock.add(frame(struk)), isTrue);
    expect(lock.locked, isTrue);
  });

  test('frame tanpa TOTAL mengulang hitungan', () {
    final lock = ReceiptLock();
    expect(lock.add(frame(struk)), isFalse);
    expect(lock.add(frame(const ['INDOMARET', 'SUSU UHT'])), isFalse);
    expect(lock.add(frame(struk)), isFalse);
    expect(lock.add(frame(struk)), isTrue);
  });

  test('angka TOTAL goyang (salah baca) belum dianggap kebaca', () {
    final lock = ReceiptLock();
    expect(lock.add(frame(struk)), isFalse);
    expect(lock.add(frame(const ['INDOMARET', 'TOTAL  62.000'])), isFalse);
    expect(lock.add(frame(const ['INDOMARET', 'TOTAL  62.000'])), isTrue);
  });

  test('angka tanpa baris TOTAL tidak memicu foto', () {
    final lock = ReceiptLock();
    const tanpaTotal = ['Promo minggu ini', 'Diskon  25.000'];
    expect(lock.add(frame(tanpaTotal)), isFalse);
    expect(lock.add(frame(tanpaTotal)), isFalse);
    expect(lock.add(frame(tanpaTotal)), isFalse);
  });

  test('reset → mulai dari awal', () {
    final lock = ReceiptLock()..add(frame(struk));
    lock.reset();
    expect(lock.add(frame(struk)), isFalse);
  });
}
