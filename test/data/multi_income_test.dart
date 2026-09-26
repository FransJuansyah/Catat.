import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Multi pemasukan: uang jajan (pelajar) & penghasilan tidak tetap.
void main() {
  late AppDatabase db;
  late DateTime now;
  late BudgetRepository repo;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    now = DateTime(2026, 9, 26, 10); // Sabtu
    repo = BudgetRepository(db, () => now);
  });
  tearDown(() => db.close());

  Future<String> pocketOf(PocketType t) async =>
      (await db.select(db.pockets).get()).firstWhere((p) => p.type == t).id;

  group('uang jajan mingguan (pelajar)', () {
    setUp(
      () => repo.setupBudget(
        incomeMode: IncomeMode.allowance,
        frequency: IncomeFrequency.weekly,
        weekday: 1,
        netSalary: 350000,
        template: PocketTemplates.pelajar,
      ),
    );

    test('uang jajan masuk otomatis tiap Senin, dibagi 50/20/30', () async {
      final home = await repo.loadHome();
      expect(home.mode, IncomeMode.allowance);
      expect(home.salary, 350000);
      expect(home.remaining, 350000);
      expect(home.periodNoun, 'minggu ini');
      expect(home.hint, 'Uang jajan masuk Senin, 2 hari lagi');
      expect(
        {for (final p in home.pockets) p.name: p.balance.allocation},
        {'Jajan & Makan': 175000, 'Tabungan': 70000, 'Seneng-seneng': 105000},
      );
    });

    test('jatah aman per hari = sisa / hari sampai Senin', () async {
      await repo.addExpense(
        pocketId: await pocketOf(PocketType.wajib),
        amount: 205000,
        title: 'Jajan',
      );
      final home = await repo.loadHome();
      expect(home.remaining, 145000);
      expect(home.dailySafe, 72500);
      expect(home.dailySafeUntil, 'Senin');
    });

    test('Senin berikutnya saldo di-reset dengan uang jajan baru', () async {
      await repo.addExpense(
        pocketId: await pocketOf(PocketType.wajib),
        amount: 100000,
        title: 'Jajan',
      );
      now = DateTime(2026, 9, 28, 7);
      final home = await repo.loadHome();
      expect(home.remaining, 350000);
      final payday = await repo.loadPayday();
      expect(payday.mode, IncomeMode.allowance);
      expect(payday.celebrated, isFalse);
    });
  });

  group('penghasilan tidak tetap', () {
    setUp(
      () => repo.setupBudget(
        incomeMode: IncomeMode.irregular,
        netSalary: 0,
        template: PocketTemplates.freelancer,
      ),
    );

    test('mulai dari 0, tiap pemasukan langsung dibagi ke kantong', () async {
      var home = await repo.loadHome();
      expect(home.remaining, 0);
      expect(home.hint, 'Belum ada pemasukan, tambah yuk');
      expect(
        (await repo.loadPayday()).celebrated,
        isTrue,
      ); // tidak ada layar gajian

      final id = await repo.addIncome(amount: 250000, title: 'Ngojek seharian');
      home = await repo.loadHome();
      expect(home.remaining, 250000);
      expect(home.monthIncome, 250000);
      expect(home.hint, 'Terakhir masuk hari ini, +Rp 250rb');
      expect(
        {for (final p in home.pockets) p.name: p.balance.allocation},
        {'Kebutuhan': 125000, 'Dana Darurat': 75000, 'Keinginan': 50000},
      );

      final detail = await repo.loadIncome(id);
      expect(detail!.allocations.map((a) => a.$2), [125000, 75000, 50000]);
      expect(detail.monthTotal, 250000);
    });

    test('saldo berjalan tidak di-reset saat ganti bulan', () async {
      await repo.addIncome(amount: 1000000, title: 'Project');
      await repo.addExpense(
        pocketId: await pocketOf(PocketType.wajib),
        amount: 200000,
        title: 'Makan',
      );
      now = DateTime(2026, 10, 3, 9);
      var home = await repo.loadHome();
      expect(home.remaining, 800000);
      expect(home.monthIncome, 0); // bulan baru belum ada pemasukan
      await repo.addIncome(amount: 300000, title: 'Jualan');
      home = await repo.loadHome();
      expect(home.remaining, 1100000);
      expect(home.monthIncome, 300000);
    });

    test('boleh mencatat pemasukan tanggal bulan lalu', () async {
      await repo.addIncome(
        amount: 50000,
        title: 'Tip',
        occurredAt: DateTime(2026, 8, 15, 12),
      );
      expect((await repo.loadHome()).remaining, 50000);
      expect(
        () => repo.addIncome(
          amount: 1000,
          title: 'x',
          occurredAt: DateTime(2026, 10, 5),
        ),
        throwsStateError,
      );
    });

    test('hapus pemasukan menarik lagi dari kantong', () async {
      final id = await repo.addIncome(amount: 250000, title: 'Ngojek');
      await repo.deleteIncome(id);
      expect((await repo.loadHome()).remaining, 0);
      expect(await repo.loadIncome(id), isNull);
    });

    test('catatan harian & kalender menampilkan pemasukan', () async {
      await repo.addIncome(
        amount: 250000,
        title: 'Ngojek',
        occurredAt: DateTime(2026, 9, 26, 20, 10),
      );
      await repo.addIncome(
        amount: 150000,
        title: 'Jualan',
        occurredAt: DateTime(2026, 9, 5, 9),
      );
      await repo.addExpense(
        pocketId: await pocketOf(PocketType.wajib),
        amount: 25000,
        title: 'Makan',
        occurredAt: DateTime(2026, 9, 26, 9),
      );

      final day = await repo.loadDay(DateTime(2026, 9, 26));
      expect(day.incomes.map((i) => i.title), ['Ngojek']);
      expect(day.incomeTotal, 250000);
      expect(day.total, 25000);

      final month = await repo.loadMonth(2026, 9);
      expect(month.incomeDays, {5, 26});
      expect(month.paydayDay, isNull);
    });

    test('detail kantong: saldo berjalan tanpa hari gajian', () async {
      await repo.addIncome(amount: 200000, title: 'Project');
      final detail = await repo.loadPocket(await pocketOf(PocketType.wajib));
      expect(detail!.daysToPayday, isNull);
      expect(detail.pocket.balance.remaining, 100000);
    });
  });

  test(
    'gaji bulanan: hari gajian muncul sebagai pemasukan otomatis di catatan',
    () async {
      await repo.setupBudget(
        netSalary: 6500000,
        payday: 25,
        template: PocketTemplates.klasik,
      );
      await repo.ensureCurrentPeriod();
      final day = await repo.loadDay(DateTime(2026, 9, 25));
      expect(day.incomes.single.title, 'Gajian');
      expect(day.incomes.single.auto, isTrue);
      expect((await repo.loadMonth(2026, 9)).incomeDays, {25});
    },
  );

  test('onboarding penghasilan tidak tetap via Riverpod', () async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    final ctrl = container.read(onboardingProvider.notifier)
      ..setMode(IncomeMode.irregular);
    expect(
      container.read(onboardingProvider).template,
      PocketTemplates.freelancer,
    );
    expect(container.read(onboardingProvider).amountReady, isTrue);
    ctrl.setMonthlyEstimate(3000000);
    await ctrl.finish();

    final settings = await db.select(db.salarySettings).getSingle();
    expect(settings.incomeMode, IncomeMode.irregular);
    expect(settings.monthlyEstimate, 3000000);
    expect(settings.incomeReminder, isTrue);
    expect((await repo.loadHome()).remaining, 0);
  });
}
