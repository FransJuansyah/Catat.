import 'package:catat/domain/report.dart';
import 'package:catat/domain/types.dart';
import 'package:catat/domain/usage_charts.dart';
import 'package:catat/domain/views.dart';
import 'package:flutter_test/flutter_test.dart';

const wajib = PocketRef(
  id: 'w',
  type: PocketType.wajib,
  name: 'Wajib',
  iconKey: 'house',
  color: 0xFF6D5DFC,
);
const ingin = PocketRef(
  id: 'k',
  type: PocketType.keinginan,
  name: 'Keinginan',
  iconKey: 'sparkles',
  color: 0xFFFF4F7B,
);

ReportExpense exp(
  DateTime at,
  int amount, {
  String title = 'Makan',
  PocketRef pocket = wajib,
  ExpenseSource source = ExpenseSource.manual,
}) => ReportExpense(
  occurredAt: at,
  title: title,
  pocket: pocket,
  amount: amount,
  source: source,
);

IncomeEntry inc(DateTime at, int amount) =>
    IncomeEntry(id: '$at', title: 'Gajian', amount: amount, occurredAt: at);

void main() {
  final today = DateTime(2026, 9, 15, 20);

  group('weekUsage', () {
    test('7 hari terakhir, puncak & insight', () {
      final w = weekUsage([
        exp(DateTime(2026, 9, 9, 8), 100000),
        exp(DateTime(2026, 9, 10, 8), 100000),
        exp(DateTime(2026, 9, 13, 12), 450000),
        exp(DateTime(2026, 9, 13, 19), 30000),
        exp(DateTime(2026, 9, 15, 7), 150000),
        exp(DateTime(2026, 9, 8, 7), 999000), // di luar 7 hari
        exp(DateTime(2026, 9, 14), 500000, source: ExpenseSource.adjust),
      ], today);
      expect(w.days.first, DateTime(2026, 9, 9));
      expect(w.days.last, DateTime(2026, 9, 15));
      expect(w.totals, [100000, 100000, 0, 0, 480000, 0, 150000]);
      expect(w.peakIndex, 4);
      expect(
        w.insight((d) => 'Sabtu'),
        'Sabtu kamu keluar 4x lipat dari biasanya.',
      );
    });

    test('kosong', () {
      final w = weekUsage([], today);
      expect(w.total, 0);
      expect(w.peakIndex, 6);
      expect(w.insight((_) => ''), contains('Belum ada pengeluaran'));
    });
  });

  group('balanceLevels', () {
    test('bulan berjalan memakai saldo sekarang', () {
      final b = balanceLevels(
        month: DateTime(2026, 9),
        today: today,
        endBalance: 500000,
        expenses: [
          exp(DateTime(2026, 9, 2), 300000),
          exp(DateTime(2026, 9, 10), 200000),
        ],
        incomes: [inc(DateTime(2026, 9, 1), 1000000)],
      );
      // Saldo awal = 500rb - (1jt - 500rb) = 0 → 1jt, 700rb, ..., 500rb.
      expect(b.levels, hasLength(30));
      expect(b.levels[0], 1.0);
      expect(b.levels[1], closeTo(0.7, 1e-9));
      expect(b.levels[14], closeTo(0.5, 1e-9));
      expect(b.levels[15], isNull);
      expect(b.incomeDays, {1});
    });

    test('bulan lalu: titik terendah = 0', () {
      final b = balanceLevels(
        month: DateTime(2026, 8),
        today: today,
        expenses: [exp(DateTime(2026, 8, 5), 400000)],
        incomes: [inc(DateTime(2026, 8, 25), 1000000)],
      );
      expect(b.levels, hasLength(31));
      expect(b.levels.every((l) => l != null), isTrue);
      expect(b.levels[4], 0.0);
      expect(b.levels[30], 1.0);
    });
  });

  test('topSpending: per kategori, terbesar dulu', () {
    final top = topSpending([
      exp(today, 1200000, title: 'Bayar kos'),
      exp(today, 25000, title: 'Kopi susu', pocket: ingin),
      exp(today, 30000, title: 'Es kopi', pocket: ingin),
      exp(today, 40000, title: 'Makan siang'),
      exp(today, 35000, title: 'Nasi padang'),
      exp(today, 15000, title: 'Buku tulis'),
      exp(today, 900000, title: 'Selisih', source: ExpenseSource.adjust),
    ]);
    expect(top.map((g) => g.label), [
      'Kos & rumah',
      'Makan',
      'Kopi & jajan',
      'Buku tulis',
    ]);
    expect(top[1].count, 2);
    expect(top[1].total, 75000);
    expect(top[2].pocket.id, 'k');
  });
}
