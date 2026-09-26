import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/report.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:catat/domain/views.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ubah pemasukan & Sesuaikan saldo (samakan dengan uang asli user).
void main() {
  late AppDatabase db;
  late BudgetRepository repo;
  final now = DateTime(2026, 9, 26, 10);

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = BudgetRepository(db, () => now);
    await repo.setupBudget(
      incomeMode: IncomeMode.irregular,
      netSalary: 0,
      template: PocketTemplates.freelancer,
    );
  });
  tearDown(() => db.close());

  Future<int> remaining() async => (await repo.loadHome()).remaining;

  group('ubah pemasukan', () {
    test('nominal salah ketik: saldo & jatah kantong ikut dikoreksi', () async {
      final id = await repo.addIncome(amount: 500000, title: 'Ngojek');
      expect(await remaining(), 500000);

      await repo.updateIncome(
        id,
        amount: 50000,
        title: 'Ngojek sore',
        occurredAt: now,
      );
      expect(await remaining(), 50000);
      final detail = (await repo.loadIncome(id))!;
      expect(detail.entry.title, 'Ngojek sore');
      expect(detail.allocations.fold<int>(0, (s, a) => s + a.$2), 50000);
    });

    test('bisa diubah berkali-kali (satu baris per kantong)', () async {
      final id = await repo.addIncome(amount: 100000, title: 'Project');
      for (final amount in [120000, 90000, 100000]) {
        await repo.updateIncome(
          id,
          amount: amount,
          title: 'Project',
          occurredAt: now,
        );
        expect(await remaining(), amount);
      }
    });
  });

  group('sesuaikan saldo', () {
    test('uang asli lebih kecil: kurangi dari kantong pilihan', () async {
      await repo.addIncome(amount: 300000, title: 'Ngojek');
      final pocket = (await repo.loadHome()).pockets.last;
      final diff = await repo.adjustBalance(
        actual: 250000,
        pocketId: pocket.id,
      );
      expect(diff, -50000);
      expect(await remaining(), 250000);
      final home = await repo.loadHome();
      final after = home.pockets.firstWhere((p) => p.id == pocket.id);
      expect(after.balance.spent, 50000);
    });

    test('uang asli lebih besar: jadi pemasukan dibagi ke kantong', () async {
      await repo.addIncome(amount: 100000, title: 'Ngojek');
      final pocket = (await repo.loadHome()).pockets.first;
      final diff = await repo.adjustBalance(
        actual: 400000,
        pocketId: pocket.id,
      );
      expect(diff, 300000);
      expect(await remaining(), 400000);
    });

    test('sudah sama: tidak mencatat apa-apa', () async {
      await repo.addIncome(amount: 100000, title: 'Ngojek');
      final pocket = (await repo.loadHome()).pockets.first;
      expect(await repo.adjustBalance(actual: 100000, pocketId: pocket.id), 0);
      final day = await repo.loadDay(now);
      expect(day.items, isEmpty);
    });
  });

  test('insight tidak menganggap penyesuaian sebagai jajan terbesar', () {
    const pocket = PocketRef(
      id: 'k',
      type: PocketType.keinginan,
      name: 'Keinginan',
      iconKey: 'sparkles',
      color: 0,
    );
    final range = ReportRange.of(ReportSpan.month, now);
    ReportExpense e(int amount, String title, ExpenseSource source) =>
        ReportExpense(
          occurredAt: now,
          title: title,
          pocket: pocket,
          amount: amount,
          source: source,
        );
    final data = ReportData(
      range: range,
      mode: IncomeMode.irregular,
      pockets: const [PocketReport(pocket: pocket, spent: 0, budget: 0)],
      months: const [],
      expenses: [
        e(500000, 'Penyesuaian saldo', ExpenseSource.adjust),
        e(25000, 'Kopi', ExpenseSource.manual),
      ],
      incomes: const [],
    );
    expect(
      buildInsight(data, null)!.text,
      'Pengeluaran terbesar: Kopi di kantong Keinginan.',
    );
  });
}
