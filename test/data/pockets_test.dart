import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// F4: atur kantong, pindah saldo, sisa akhir periode ke Dana Darurat.
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
    now = DateTime(2026, 9, 26, 10);
    repo = BudgetRepository(db, () => now);
  });
  tearDown(() => db.close());

  Future<void> setupSalary() => repo.setupBudget(
    netSalary: 6500000,
    payday: 25,
    template: PocketTemplates.klasik,
  );

  Map<String, int> allocations(List<dynamic> pockets) => {
    for (final p in pockets) p.name as String: p.balance.allocation as int,
  };

  test(
    'simpan kantong: nama, ikon, warna, urutan & jatah ikut berubah',
    () async {
      await setupSalary();
      final setup = await repo.loadPocketSetup();
      expect(setup.base, 6500000);
      final [wajib, darurat, ingin] = setup.pockets;
      await repo.savePockets([
        ingin.copyWith(
          name: 'Healing & Jajan',
          iconKey: 'coffee',
          color: 0xFFFF8A00,
          percent: 25,
        ),
        wajib.copyWith(percent: 50),
        darurat.copyWith(percent: 25),
      ]);

      final home = await repo.loadHome();
      expect(home.pockets.map((p) => p.name), [
        'Healing & Jajan',
        'Wajib',
        'Darurat',
      ]);
      expect(home.pockets.first.iconKey, 'coffee');
      expect(allocations(home.pockets), {
        'Healing & Jajan': 1625000,
        'Wajib': 3250000,
        'Darurat': 1625000,
      });
    },
  );

  test('nama kosong / rentang terbalik ditolak', () async {
    await setupSalary();
    final p = (await repo.loadPocketSetup()).pockets.first;
    expect(
      () => repo.savePockets([p.copyWith(name: '  ')]),
      throwsArgumentError,
    );
    expect(
      () => repo.savePockets([
        p.copyWith(rangeMin: () => 3000000, rangeMax: () => 1000000),
      ]),
      throwsArgumentError,
    );
  });

  test('rentang maksimal membatasi jatah periode', () async {
    await setupSalary();
    final [w, d, k] = (await repo.loadPocketSetup()).pockets;
    await repo.savePockets([w, d, k.copyWith(rangeMax: () => 1500000)]);
    final home = await repo.loadHome();
    expect(home.pockets.last.balance.allocation, 1500000);
  });

  test('pindahin saldo antar kantong', () async {
    await setupSalary();
    final [w, d, k] = (await repo.loadPocketSetup()).pockets;
    await repo.transferBalance(
      fromPocketId: d.id,
      toPocketId: k.id,
      amount: 200000,
    );
    final home = await repo.loadHome();
    final byName = {for (final p in home.pockets) p.name: p.balance};
    expect(byName['Darurat']!.remaining, 1100000);
    expect(byName['Keinginan']!.remaining, 2150000);
    expect(home.remaining, 6500000); // total tidak berubah
    expect(
      () => repo.transferBalance(
        fromPocketId: d.id,
        toPocketId: w.id,
        amount: 5000000,
      ),
      throwsStateError,
    );
  });

  test('sisa akhir bulan pindah ke Dana Darurat periode berikutnya', () async {
    await setupSalary();
    final [w, d, k] = (await repo.loadPocketSetup()).pockets;
    await repo.savePockets([w, d, k.copyWith(rolloverToEmergency: true)]);
    await repo.addExpense(pocketId: k.id, amount: 950000, title: 'Nonton');

    now = DateTime(2026, 10, 25, 8); // gajian berikutnya
    final home = await repo.loadHome();
    final byName = {for (final p in home.pockets) p.name: p.balance};
    // Keinginan sisa 1.000.000 → masuk Darurat periode baru.
    expect(byName['Darurat']!.available, 1300000 + 1000000);
    expect(byName['Keinginan']!.available, 1950000);
    // Dipanggil ulang tidak dobel.
    expect((await repo.loadHome()).remaining, 6500000 + 1000000);
  });

  test('peringatan hampir habis bisa dimatikan', () async {
    await setupSalary();
    final [w, d, k] = (await repo.loadPocketSetup()).pockets;
    await repo.addExpense(pocketId: k.id, amount: 1800000, title: 'Sepatu');
    expect((await repo.loadHome()).pockets.last.isLow, isTrue);
    await repo.savePockets([w, d, k.copyWith(lowThresholdPercent: 0)]);
    expect((await repo.loadHome()).pockets.last.isLow, isFalse);
  });

  test(
    'penghasilan tidak tetap: aturan baru untuk pemasukan berikutnya',
    () async {
      await repo.setupBudget(
        incomeMode: IncomeMode.irregular,
        netSalary: 0,
        monthlyEstimate: 3000000,
        template: PocketTemplates.freelancer,
      );
      await repo.addIncome(amount: 100000, title: 'Ngojek');
      final setup = await repo.loadPocketSetup();
      expect(setup.isRunning, isTrue);
      expect(setup.base, 3000000);
      final [a, b, c] = setup.pockets;
      await repo.savePockets([
        a.copyWith(percent: 60),
        b.copyWith(percent: 20),
        c.copyWith(percent: 20),
      ]);
      await repo.addIncome(amount: 100000, title: 'Ngojek');
      final home = await repo.loadHome();
      expect(allocations(home.pockets), {
        'Kebutuhan': 50000 + 60000,
        'Dana Darurat': 30000 + 20000,
        'Keinginan': 20000 + 20000,
      });
    },
  );

  test(
    'draft Atur Kantong: tab nominal, geser urutan, rapiin, simpan',
    () async {
      await setupSalary();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(pocketDraftProvider, (_, _) {});
      addTearDown(sub.close);
      final ctrl = container.read(pocketDraftProvider.notifier);
      var draft = await container.read(pocketDraftProvider.future);
      expect(draft.dirty, isFalse);

      final ingin = draft.current.pockets.last;
      ctrl.updatePocket(ingin.copyWith(percent: 40));
      draft = container.read(pocketDraftProvider).value!;
      expect(draft.current.check.displayPercent, 110);
      expect(draft.lastEditedId, ingin.id);

      ctrl.autoBalance();
      draft = container.read(pocketDraftProvider).value!;
      expect(draft.current.check.isValid, isTrue);

      ctrl.setAllMode(AllocationMode.nominal);
      ctrl.reorder(2, 0);
      draft = container.read(pocketDraftProvider).value!;
      expect(draft.current.pockets.first.id, ingin.id);
      expect(draft.current.pockets.first.mode, AllocationMode.nominal);
      expect(draft.current.check.isValid, isTrue);
      expect(draft.dirty, isTrue);

      await ctrl.save();
      expect(container.read(pocketDraftProvider).value!.dirty, isFalse);
      final home = await repo.loadHome();
      expect(home.pockets.first.id, ingin.id);
      expect(
        home.pockets.fold<int>(0, (s, p) => s + p.balance.allocation),
        6500000,
      );
    },
  );
}
