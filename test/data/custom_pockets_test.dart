import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/pocket_config.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kantong bebas 2–6 (layar 20/21/43/45) & saldo awal saat daftar (layar 42).
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

  Map<String, int> remaining(List<dynamic> pockets) => {
    for (final p in pockets) p.name as String: p.balance.remaining as int,
  };

  group('saldo awal (layar 42)', () {
    test(
      'periode pertama dibagi dari saldo awal, gajian berikutnya normal',
      () async {
        await setupSalary();
        await repo.setOpeningBalance(2000000);

        var home = await repo.loadHome();
        expect(home.opening, 2000000);
        expect(home.remaining, 2000000);
        expect(remaining(home.pockets), {
          'Wajib': 1000000,
          'Darurat': 400000,
          'Keinginan': 600000,
        });
        expect((await repo.loadPayday()).celebrated, isTrue);

        // Ubah jatah di periode ini tetap dari saldo awal.
        final setup = await repo.loadPocketSetup();
        expect(setup.fromOpening, isTrue);
        expect(setup.base, 2000000);
        final [w, d, k] = setup.pockets;
        await repo.savePockets([
          w.copyWith(percent: 60),
          d.copyWith(percent: 20),
          k.copyWith(percent: 20),
        ]);
        expect(
          (await repo.loadHome()).pockets.first.balance.allocation,
          1200000,
        );

        now = DateTime(2026, 10, 25, 8);
        home = await repo.loadHome();
        expect(home.opening, isNull);
        expect(home.salary, 6500000);
        expect(home.pockets.first.balance.allocation, 3900000);
      },
    );

    test('isi gaji periode itu menggantikan saldo awal', () async {
      await setupSalary();
      await repo.setOpeningBalance(2000000);
      final info = await repo.loadPayday();
      await repo.setPeriodSalary(info.periodId, 6500000);
      final home = await repo.loadHome();
      expect(home.opening, isNull);
      expect(home.remaining, 6500000);
    });
  });

  group('tambah & hapus kantong', () {
    test('tambah kantong ke-4 dengan jenis sendiri', () async {
      await setupSalary();
      final setup = await repo.loadPocketSetup();
      final [w, d, k] = setup.pockets;
      final cicilan = newPocket(
        'cicilan',
        setup.pockets,
        icons: pocketIconChoices,
        colors: pocketPalette,
      ).copyWith(name: 'Cicilan HP', type: PocketType.wajib, percent: 10);
      expect(cicilan.iconKey, isNot(anyOf('house', 'shield', 'sparkles')));
      await repo.savePockets([w.copyWith(percent: 40), d, k, cicilan]);

      final home = await repo.loadHome();
      expect(home.pockets.map((p) => p.name), [
        'Wajib',
        'Darurat',
        'Keinginan',
        'Cicilan HP',
      ]);
      expect(home.pockets.last.type, PocketType.wajib);
      expect(home.pockets.last.balance.allocation, 650000);
      expect(home.remaining, 6500000);
    });

    test('jumlah kantong harus 2 sampai 6', () async {
      await setupSalary();
      final pockets = (await repo.loadPocketSetup()).pockets;
      expect(
        () => repo.savePockets([pockets.first.copyWith(percent: 100)]),
        throwsArgumentError,
      );
      var list = pockets;
      for (var i = 0; i < 4; i++) {
        list = [
          ...list,
          newPocket(
            'x$i',
            list,
            icons: pocketIconChoices,
            colors: pocketPalette,
          ),
        ];
      }
      expect(list, hasLength(7));
      expect(() => repo.savePockets(list), throwsArgumentError);
    });

    test('kantong tidak boleh hilang tanpa tujuan pindah', () async {
      await setupSalary();
      final [w, d, _] = (await repo.loadPocketSetup()).pockets;
      expect(
        () => repo.savePockets([w.copyWith(percent: 80), d]),
        throwsArgumentError,
      );
    });

    test(
      'hapus kantong: saldo, catatan & pindah saldo ikut ke tujuan',
      () async {
        await setupSalary();
        final [w, d, k] = (await repo.loadPocketSetup()).pockets;
        await repo.addExpense(pocketId: k.id, amount: 150000, title: 'Kopi');
        await repo.addExpense(pocketId: k.id, amount: 50000, title: 'Parkir');
        await repo.transferBalance(
          fromPocketId: d.id,
          toPocketId: k.id,
          amount: 100000,
        );
        final usage = await repo.pocketUsage(k.id);
        expect(usage.entries, 2);
        expect(usage.remaining, 1950000 - 200000 + 100000);
        final before = (await repo.loadHome()).remaining;

        final kept = withoutPocket([w, d, k], k.id, w.id, 6500000);
        expect(kept.first.percent, 80);
        await repo.savePockets(kept, moves: {k.id: w.id});

        final home = await repo.loadHome();
        expect(home.pockets.map((p) => p.name), ['Wajib', 'Darurat']);
        expect(home.remaining, before);
        final wajib = home.pockets.first.balance;
        expect(wajib.allocation, 5200000);
        expect(wajib.spent, 200000);
        expect(wajib.transferIn, 100000);
        final expenses = await db.select(db.expenses).get();
        expect(expenses.every((e) => e.pocketId == w.id), isTrue);
        final deleted = await (db.select(
          db.pockets,
        )..where((t) => t.id.equals(k.id))).getSingle();
        expect(deleted.deletedAt, isNotNull);
      },
    );

    test(
      'hapus kantong di periode lalu: riwayat bulan lalu tetap utuh',
      () async {
        await setupSalary();
        final [w, d, k] = (await repo.loadPocketSetup()).pockets;
        await repo.addExpense(pocketId: k.id, amount: 300000, title: 'Nonton');
        final lastMonth = (await repo.loadPayday()).periodId;

        now = DateTime(2026, 10, 26, 10);
        await repo.savePockets(
          withoutPocket([w, d, k], k.id, d.id, 6500000),
          moves: {k.id: d.id},
        );
        final allocs =
            await (db.select(db.periodAllocations)..where(
                  (t) => t.periodId.equals(lastMonth) & t.deletedAt.isNull(),
                ))
                .get();
        // Jatah Keinginan bulan lalu pindah ke Darurat, total tetap 6,5 jt.
        expect(allocs.fold<int>(0, (s, a) => s + a.amount), 6500000);
        expect(allocs.map((a) => a.pocketId).toSet(), {w.id, d.id});
      },
    );

    test('penghasilan tidak tetap: saldo berjalan pindah utuh', () async {
      await repo.setupBudget(
        netSalary: 0,
        incomeMode: IncomeMode.irregular,
        template: PocketTemplates.freelancer,
      );
      await repo.setOpeningBalance(1000000);
      await repo.addIncome(amount: 2000000, title: 'Proyek');
      final [w, d, k] = (await repo.loadPocketSetup()).pockets;
      await repo.addExpense(pocketId: k.id, amount: 100000, title: 'Jajan');
      final before = remaining((await repo.loadHome()).pockets);

      await repo.savePockets(
        withoutPocket([w, d, k], k.id, d.id, 0),
        moves: {k.id: d.id},
      );
      final after = remaining((await repo.loadHome()).pockets);
      expect(after['Kebutuhan'], before['Kebutuhan']);
      expect(
        after['Dana Darurat'],
        before['Dana Darurat']! + before['Keinginan']!,
      );
      expect(after.keys, ['Kebutuhan', 'Dana Darurat']);
    });
  });

  group('draft kantong (Riverpod)', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('bikin sendiri saat daftar (43) lalu saldo awal (42)', () async {
      final c = container();
      final sub = c.listen(pocketDraftProvider, (_, _) {});
      addTearDown(sub.close);
      c.read(onboardingProvider.notifier)
        ..setAmount(5000000)
        ..setPayday(25);
      final ctrl = c.read(pocketDraftProvider.notifier);
      var draft = await c.read(pocketDraftProvider.future);
      expect(draft.onboarding, isTrue);
      expect(draft.current.pockets, hasLength(3));

      // Tambah "Cicilan" 10%, hapus Keinginan → jatahnya ke Wajib.
      final id = ctrl.addPocket()!;
      draft = c.read(pocketDraftProvider).value!;
      ctrl.updatePocket(
        draft
            .pocket(id)
            .copyWith(name: 'Cicilan', type: PocketType.wajib, percent: 10),
      );
      final [w, _, k, _] = c.read(pocketDraftProvider).value!.current.pockets;
      ctrl.updatePocket(w.copyWith(percent: 40));
      ctrl.removePocket(k.id, w.id);
      draft = c.read(pocketDraftProvider).value!;
      expect(draft.moves, isEmpty); // belum tersimpan, tidak ada yang dipindah
      expect(draft.current.check.isValid, isTrue);
      await ctrl.save();

      final template = c.read(onboardingProvider).template;
      expect(template.name, PocketTemplates.customName);
      expect(template.pockets.map((p) => (p.name, p.percent)), [
        ('Wajib', 70),
        ('Darurat', 20),
        ('Cicilan', 10),
      ]);

      await c.read(onboardingProvider.notifier).finish(opening: 1000000);
      final home = await repo.loadHome();
      expect(home.pockets.map((p) => p.name), ['Wajib', 'Darurat', 'Cicilan']);
      expect(home.pockets.last.type, PocketType.wajib);
      expect(remaining(home.pockets), {
        'Wajib': 700000,
        'Darurat': 200000,
        'Cicilan': 100000,
      });
    });

    test('hapus berantai: tujuan yang ikut dihapus diarahkan ulang', () async {
      await setupSalary();
      final c = container();
      final sub = c.listen(pocketDraftProvider, (_, _) {});
      addTearDown(sub.close);
      final ctrl = c.read(pocketDraftProvider.notifier);
      final draft = await c.read(pocketDraftProvider.future);
      expect(draft.onboarding, isFalse);
      final [w, d, k] = draft.current.pockets;
      final extra = ctrl.addPocket()!;
      ctrl.removePocket(k.id, d.id);
      ctrl.removePocket(d.id, w.id);
      final after = c.read(pocketDraftProvider).value!;
      expect(after.moves, {k.id: w.id, d.id: w.id});
      expect(after.current.pockets.map((p) => p.id), [w.id, extra]);
      expect(after.current.pockets.first.percent, 100);
      // Sudah 2 kantong → tidak bisa hapus lagi.
      ctrl.removePocket(extra, w.id);
      expect(c.read(pocketDraftProvider).value!.current.pockets, hasLength(2));
      await ctrl.save();
      expect((await repo.loadHome()).pockets, hasLength(2));
    });
  });
}
