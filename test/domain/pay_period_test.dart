import 'package:catat/domain/pay_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayPeriod.containing', () {
    test('setelah tanggal gajian → periode mulai bulan ini', () {
      final p = PayPeriod.containing(DateTime(2026, 9, 26, 14), 25);
      expect(p.start, DateTime(2026, 9, 25));
      expect(p.end, DateTime(2026, 10, 24));
    });

    test('sebelum tanggal gajian → periode mulai bulan lalu', () {
      final p = PayPeriod.containing(DateTime(2026, 9, 24), 25);
      expect(p.start, DateTime(2026, 8, 25));
      expect(p.end, DateTime(2026, 9, 24));
    });

    test('tepat di hari gajian → periode baru', () {
      final p = PayPeriod.containing(DateTime(2026, 9, 25), 25);
      expect(p.start, DateTime(2026, 9, 25));
    });

    test('gajian tgl 31 dijepit ke akhir Februari', () {
      final p = PayPeriod.containing(DateTime(2026, 3, 10), 31);
      expect(p.start, DateTime(2026, 2, 28));
      expect(p.end, DateTime(2026, 3, 30));
    });

    test('tahun kabisat: gajian tgl 30 → 29 Februari', () {
      final p = PayPeriod.containing(DateTime(2028, 3, 1), 30);
      expect(p.start, DateTime(2028, 2, 29));
      expect(p.end, DateTime(2028, 3, 29));
    });

    test('lintas tahun Desember → Januari', () {
      final p = PayPeriod.containing(DateTime(2027, 1, 5), 25);
      expect(p.start, DateTime(2026, 12, 25));
      expect(p.end, DateTime(2027, 1, 24));
    });

    test('gajian tgl 1', () {
      final p = PayPeriod.containing(DateTime(2026, 9, 30), 1);
      expect(p.start, DateTime(2026, 9, 1));
      expect(p.end, DateTime(2026, 9, 30));
    });
  });

  test('hitung hari menuju gajian & porsi berjalan', () {
    final p = PayPeriod.containing(DateTime(2026, 9, 24), 25);
    expect(p.daysUntilNextPayday(DateTime(2026, 9, 24, 23)), 1);
    expect(p.daysUntilNextPayday(DateTime(2026, 8, 25)), 31);
    expect(p.lengthInDays, 31);
    expect(p.elapsedRatio(DateTime(2026, 9, 24)), 1);
    expect(p.contains(DateTime(2026, 9, 24, 23, 59)), isTrue);
    expect(p.contains(DateTime(2026, 9, 25)), isFalse);
  });
}
