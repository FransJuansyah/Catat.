import 'package:catat/domain/allocation.dart';
import 'package:catat/domain/income_schedule.dart';
import 'package:catat/domain/pay_period.dart';
import 'package:catat/domain/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('periode baru', () {
    test('mingguan mulai hari Senin terakhir', () {
      // 26 Sep 2026 = Sabtu.
      final p = PayPeriod.weekly(DateTime(2026, 9, 26, 15), 1);
      expect(p.start, DateTime(2026, 9, 21));
      expect(p.end, DateTime(2026, 9, 27));
      expect(p.daysUntilNextPayday(DateTime(2026, 9, 26)), 2);
    });

    test('mingguan tepat di harinya → periode baru', () {
      final p = PayPeriod.weekly(DateTime(2026, 9, 28), 1);
      expect(p.start, DateTime(2026, 9, 28));
    });

    test('harian & bulan kalender', () {
      expect(
        PayPeriod.daily(DateTime(2026, 9, 26, 22)).start,
        DateTime(2026, 9, 26),
      );
      final m = PayPeriod.calendarMonth(DateTime(2026, 2, 10));
      expect(m.start, DateTime(2026, 2, 1));
      expect(m.end, DateTime(2026, 2, 28));
    });
  });

  group('IncomeSchedule', () {
    test('gaji selalu bulanan walau frekuensi lain tersimpan', () {
      const s = IncomeSchedule(
        mode: IncomeMode.salary,
        frequency: IncomeFrequency.weekly,
        payday: 25,
      );
      expect(s.effectiveFrequency, IncomeFrequency.monthly);
      expect(s.periodFor(DateTime(2026, 9, 26)).start, DateTime(2026, 9, 25));
      expect(s.periodNoun, 'bulan ini');
    });

    test('uang jajan mingguan & tidak tetap', () {
      const jajan = IncomeSchedule(
        mode: IncomeMode.allowance,
        frequency: IncomeFrequency.weekly,
        weekday: 1,
      );
      expect(jajan.periodNoun, 'minggu ini');
      expect(jajan.perNoun, 'minggu');
      const bebas = IncomeSchedule(mode: IncomeMode.irregular);
      expect(bebas.isRunningBalance, isTrue);
      expect(
        bebas.periodFor(DateTime(2026, 9, 26)).start,
        DateTime(2026, 9, 1),
      );
    });

    test('teks pemasukan berikutnya', () {
      const jajan = IncomeSchedule(
        mode: IncomeMode.allowance,
        frequency: IncomeFrequency.weekly,
        weekday: 1,
      );
      expect(
        nextIncomeHint(jajan, 2, DateTime(2026, 9, 28)),
        'Uang jajan masuk Senin, 2 hari lagi',
      );
      expect(
        nextIncomeHint(jajan, 1, DateTime(2026, 9, 28)),
        'Uang jajan masuk besok',
      );
      const gaji = IncomeSchedule(mode: IncomeMode.salary);
      expect(
        nextIncomeHint(gaji, 1, DateTime(2026, 9, 25)),
        'Gajian besok, tahan dulu ya',
      );
    });
  });

  group('splitIncome', () {
    test('Freelancer 50/30/20 dari 250rb', () {
      const rules = [
        PocketRule(pocketId: 'k', percent: 50),
        PocketRule(pocketId: 'd', percent: 30),
        PocketRule(pocketId: 'i', percent: 20),
      ];
      expect(splitIncome(250000, rules), {'k': 125000, 'd': 75000, 'i': 50000});
    });

    test('total selalu sama dengan nominal (pembulatan)', () {
      const rules = [
        PocketRule(pocketId: 'a', percent: 33),
        PocketRule(pocketId: 'b', percent: 33),
        PocketRule(pocketId: 'c', percent: 34),
      ];
      final r = splitIncome(100001, rules);
      expect(r.values.reduce((a, b) => a + b), 100001);
    });

    test('rentang min-maks tidak berlaku untuk pemasukan tambahan', () {
      const rules = [
        PocketRule(pocketId: 'a', percent: 50, rangeMax: 10),
        PocketRule(pocketId: 'b', percent: 50),
      ];
      expect(splitIncome(1000, rules), {'a': 500, 'b': 500});
    });

    test('kantong mode nominal dibagi sebanding nominalnya', () {
      const rules = [
        PocketRule(pocketId: 'a', mode: AllocationMode.nominal, nominal: 3000),
        PocketRule(pocketId: 'b', mode: AllocationMode.nominal, nominal: 1000),
      ];
      expect(splitIncome(400, rules), {'a': 300, 'b': 100});
    });
  });
}
