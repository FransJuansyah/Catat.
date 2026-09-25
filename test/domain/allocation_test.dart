import 'package:catat/domain/allocation.dart';
import 'package:catat/domain/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const klasik = [
    PocketRule(pocketId: 'w', percent: 50),
    PocketRule(pocketId: 'd', percent: 20),
    PocketRule(pocketId: 'k', percent: 30),
  ];

  test('50/20/30 dari 6,5jt sesuai desain', () {
    expect(allocateAll(6500000, klasik), {
      'w': 3250000,
      'd': 1300000,
      'k': 1950000,
    });
  });

  test('sisa pembulatan masuk ke kantong terbesar → total = gaji persis', () {
    const rules = [
      PocketRule(pocketId: 'a', percent: 33),
      PocketRule(pocketId: 'b', percent: 33),
      PocketRule(pocketId: 'c', percent: 34),
    ];
    final r = allocateAll(1000001, rules);
    expect(r.values.reduce((a, b) => a + b), 1000001);
  });

  test('jatah dijepit ke rentang min–maks', () {
    const rules = [
      PocketRule(
        pocketId: 'k',
        percent: 30,
        rangeMin: 1000000,
        rangeMax: 2500000,
      ),
    ];
    expect(allocateAll(10000000, rules)['k'], 2500000);
    expect(allocateAll(2000000, rules)['k'], 1000000);
  });

  test('mode nominal', () {
    const rules = [
      PocketRule(pocketId: 'w', mode: AllocationMode.nominal, nominal: 4000000),
      PocketRule(pocketId: 'k', mode: AllocationMode.nominal, nominal: 2500000),
    ];
    final check = AllocationCheck.of(6500000, rules);
    expect(check.isValid, isTrue);
    expect(check.displayPercent, 100);
  });

  group('AllocationCheck', () {
    test('100% → valid', () {
      final c = AllocationCheck.of(6500000, klasik);
      expect(c.isValid, isTrue);
      expect(c.difference, 0);
    });

    test('110% → kelebihan Rp 650.000 (layar 23)', () {
      const over = [
        PocketRule(pocketId: 'w', percent: 50),
        PocketRule(pocketId: 'd', percent: 20),
        PocketRule(pocketId: 'k', percent: 40),
      ];
      final c = AllocationCheck.of(6500000, over);
      expect(c.isValid, isFalse);
      expect(c.displayPercent, 110);
      expect(c.difference, 650000);
    });

    test('kurang dari 100% → belum valid, selisih negatif', () {
      const under = [PocketRule(pocketId: 'w', percent: 90)];
      final c = AllocationCheck.of(1000000, under);
      expect(c.isValid, isFalse);
      expect(c.difference, -100000);
    });
  });
}
