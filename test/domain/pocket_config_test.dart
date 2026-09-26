import 'package:catat/domain/pocket_config.dart';
import 'package:catat/domain/types.dart';
import 'package:flutter_test/flutter_test.dart';

PocketConfig _p(
  String id,
  int percent, {
  AllocationMode mode = AllocationMode.percent,
  int nominal = 0,
}) => PocketConfig(
  id: id,
  type: PocketType.wajib,
  name: id,
  iconKey: 'house',
  color: 0xFF6D5DFC,
  mode: mode,
  percent: percent,
  nominal: nominal,
);

void main() {
  group('balancePockets (Rapiin otomatis)', () {
    test('110% → dibagi ulang sebanding, total 100%', () {
      final r = balancePockets([_p('a', 50), _p('b', 20), _p('c', 40)], 0);
      expect(r.map((p) => p.percent), [46, 18, 36]);
    });

    test('kurang dari 100% juga dirapikan', () {
      final r = balancePockets([_p('a', 40), _p('b', 20), _p('c', 20)], 0);
      expect(r.map((p) => p.percent).reduce((a, b) => a + b), 100);
      expect(r.map((p) => p.percent), [50, 25, 25]);
    });

    test('semua 0% → dibagi rata', () {
      final r = balancePockets([_p('a', 0), _p('b', 0), _p('c', 0)], 0);
      expect(r.map((p) => p.percent), [34, 33, 33]);
    });

    test('mode nominal → pas sebesar gaji', () {
      const n = AllocationMode.nominal;
      final r = balancePockets([
        _p('a', 0, mode: n, nominal: 4000000),
        _p('b', 0, mode: n, nominal: 2000000),
        _p('c', 0, mode: n, nominal: 2000000),
      ], 6000000);
      expect(r.map((p) => p.nominal), [3000000, 1500000, 1500000]);
    });

    test('campuran persen + nominal tetap pas sebesar gaji', () {
      final r = balancePockets([
        _p('a', 50),
        _p('b', 0, mode: AllocationMode.nominal, nominal: 3000000),
        _p('c', 30),
      ], 6500000);
      final total = r.fold<int>(0, (s, p) => s + p.amountOf(6500000));
      expect(total, 6500000);
      expect(r[0].mode, AllocationMode.percent);
      expect(r[1].mode, AllocationMode.nominal);
    });
  });

  test('ganti satuan persen ↔ nominal', () {
    final p = _p('a', 30);
    final n = p.withMode(AllocationMode.nominal, 6500000);
    expect(n.nominal, 1950000);
    expect(n.withMode(AllocationMode.percent, 6500000).percent, 30);
  });

  test('validasi layar 20: pas, lebih, kurang', () {
    PocketSetup setup(List<PocketConfig> ps) => PocketSetup(
      incomeMode: IncomeMode.salary,
      base: 6500000,
      perNoun: 'bulan',
      pockets: ps,
    );
    expect(setup([_p('a', 50), _p('b', 20), _p('c', 30)]).check.isValid, true);
    final over = setup([_p('a', 50), _p('b', 20), _p('c', 40)]).check;
    expect(over.displayPercent, 110);
    expect(over.difference, 650000);
    expect(setup([_p('a', 50), _p('b', 20)]).check.difference, -1950000);
  });
}
