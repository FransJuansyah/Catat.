import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/data/repositories/report_repository.dart';
import 'package:catat/domain/report.dart';
import 'package:catat/domain/templates.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// F7: angka laporan harus sama dengan saldo di Beranda.
void main() {
  late AppDatabase db;
  late DateTime now;
  late BudgetRepository budget;
  late ReportRepository report;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    // Periode gajian mulai 25 Sep, jadi masuk laporan September.
    now = DateTime(2026, 9, 26, 10);
    budget = BudgetRepository(db, () => now);
    report = ReportRepository(db, () => now);
  });
  tearDown(() => db.close());

  Future<void> setupSalary() => budget.setupBudget(
    netSalary: 6500000,
    payday: 25,
    template: PocketTemplates.klasik,
  );

  Future<Map<String, PocketReport>> pocketsOf(ReportRange range) async => {
    for (final p in (await report.load(range)).pockets) p.pocket.name: p,
  };

  final sep = ReportRange.of(ReportSpan.month, DateTime(2026, 9));

  test('total keluar, pemasukan & sisa', () async {
    await setupSalary();
    await budget.ensureCurrentPeriod();
    final [w, _, k] = (await budget.loadPocketSetup()).pockets;
    await budget.addExpense(pocketId: w.id, amount: 52000, title: 'Indomaret');
    await budget.addExpense(pocketId: k.id, amount: 85000, title: 'Nonton');

    final data = await report.load(sep);
    expect(data.totalSpent, 137000);
    expect(data.totalIncome, 6500000);
    expect(data.remaining, 6500000 - 137000);
    expect(data.incomeLabel, 'Gaji masuk');
    final byName = await pocketsOf(sep);
    expect(byName['Wajib']!.spent, 52000);
    expect(byName['Wajib']!.budget, 3250000);
  });

  test('pindah saldo ikut mengubah jatah, sama dengan Beranda', () async {
    await setupSalary();
    await budget.ensureCurrentPeriod();
    final [_, d, k] = (await budget.loadPocketSetup()).pockets;
    await budget.transferBalance(
      fromPocketId: d.id,
      toPocketId: k.id,
      amount: 200000,
    );
    await budget.addExpense(pocketId: k.id, amount: 2000000, title: 'Sepatu');

    final byName = await pocketsOf(sep);
    expect(byName['Darurat']!.budget, 1300000 - 200000);
    expect(byName['Keinginan']!.budget, 1950000 + 200000);
    // Jatah laporan − terpakai = sisa di Beranda.
    final home = await budget.loadHome();
    for (final p in home.pockets) {
      final r = byName[p.name]!;
      expect(r.budget - r.spent, p.balance.remaining, reason: p.name);
    }
  });

  test('sisa akhir bulan masuk jatah Darurat bulan berikutnya', () async {
    await setupSalary();
    final [w, d, k] = (await budget.loadPocketSetup()).pockets;
    await budget.savePockets([w, d, k.copyWith(rolloverToEmergency: true)]);
    await budget.addExpense(pocketId: k.id, amount: 950000, title: 'Nonton');

    now = DateTime(2026, 10, 25, 8); // gajian berikutnya
    await budget.loadHome();

    final oct = ReportRange.of(ReportSpan.month, DateTime(2026, 10));
    final octPockets = await pocketsOf(oct);
    expect(octPockets['Darurat']!.budget, 1300000 + 1000000);
    expect(octPockets['Keinginan']!.budget, 1950000);
    // Bulan asal: sisa yang pindah keluar dari jatah Keinginan.
    expect((await pocketsOf(sep))['Keinginan']!.budget, 950000);
  });
}
