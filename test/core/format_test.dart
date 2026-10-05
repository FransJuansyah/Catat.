import 'package:catat/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rupiah penuh pakai titik ribuan', () {
    expect(rupiah(2180000), 'Rp 2.180.000');
    expect(rupiah(0), 'Rp 0');
    expect(rupiah(-450000), '-Rp 450.000');
    expect(rupiahOut(52000), '-Rp 52.000');
  });

  test('rupiah singkat', () {
    expect(rupiahShort(450000), 'Rp 450rb');
    expect(rupiahShort(1300000), 'Rp 1,3jt');
    expect(rupiahShort(1950000), 'Rp 1,95jt');
    expect(rupiahShort(3000000), 'Rp 3jt');
    expect(rupiahShort(800), 'Rp 800');
    expect(rupiahShort(-200000), '-Rp 200rb');
  });

  test('tanggal bahasa Indonesia', () {
    final d = DateTime(2026, 9, 24, 10, 5);
    expect(dayTitle(d), 'Kamis, 24 Sep');
    expect(fullDate(d), 'Kamis, 24 Sep 2026');
    expect(monthYear(d), 'Sep 2026');
    expect(monthYearLong(d), 'September 2026');
    expect(clock(d), '10:05');
    expect(dayName(DateTime(2026, 9, 27)), 'Minggu');
  });

  test('hari relatif', () {
    final today = DateTime(2026, 9, 24, 8);
    expect(relativeDay(DateTime(2026, 9, 24, 22), today), 'Hari ini');
    expect(relativeDay(DateTime(2026, 9, 23), today), 'Kemarin');
    expect(relativeDay(DateTime(2026, 9, 1), today), '1 Sep');
  });
}
