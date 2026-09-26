import 'package:catat/core/widgets/amount_keypad.dart';
import 'package:catat/data/local/database.dart';
import 'package:catat/data/providers.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/templates.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fitur F3: onboarding, gaji otomatis tiap bulan, layar Gajian Masuk.
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
    now = DateTime(2026, 9, 26, 9);
    repo = BudgetRepository(db, () => now);
  });
  tearDown(() => db.close());

  group('keypad nominal', () {
    test('ketik angka, 000, hapus', () {
      var a = 0;
      for (final k in ['6', '5', '0', '0', '000']) {
        a = applyAmountKey(a, k);
      }
      expect(a, 6500000);
      expect(applyAmountKey(a, 'del'), 650000);
      expect(applyAmountKey(0, '000'), 0);
      expect(applyAmountKey(0, '0'), 0);
    });

    test('tidak melebihi batas 11 digit', () {
      expect(applyAmountKey(maxAmount, '9'), maxAmount);
      expect(applyAmountKey(999999999, '000'), 999999999);
    });
  });

  test(
    'gaji otomatis: periode baru langsung terisi & belum dirayakan',
    () async {
      await repo.setupBudget(
        netSalary: 6500000,
        payday: 25,
        template: PocketTemplates.anakKos,
      );
      final info = await repo.loadPayday();
      expect(info.salary, 6500000);
      expect(info.needsSalary, isFalse);
      expect(info.celebrated, isFalse);
      expect(info.start, DateTime(2026, 9, 25));
      expect(info.allocations.map((a) => (a.$1.name, a.$2)), [
        ('Kos & Makan', 3900000),
        ('Tabungan', 975000),
        ('Nongkrong', 1625000),
      ]);

      await repo.markCelebrated(info.periodId);
      expect((await repo.loadPayday()).celebrated, isTrue);

      // Gajian bulan depan → periode baru, muncul lagi.
      now = DateTime(2026, 10, 25, 7);
      final next = await repo.loadPayday();
      expect(next.periodId, isNot(info.periodId));
      expect(next.celebrated, isFalse);
      expect(next.salary, 6500000);
    },
  );

  test(
    'tambah otomatis mati: gaji 0 sampai diisi, lalu dibagi ulang',
    () async {
      await repo.setupBudget(
        netSalary: 6500000,
        payday: 25,
        template: PocketTemplates.klasik,
        autoAdd: false,
      );
      final info = await repo.loadPayday();
      expect(info.needsSalary, isTrue);
      expect((await repo.loadHome()).remaining, 0);

      await repo.setPeriodSalary(info.periodId, 7000000);
      final filled = await repo.loadPayday();
      expect(filled.needsSalary, isFalse);
      expect(filled.allocations.map((a) => a.$2), [3500000, 1400000, 2100000]);
      expect((await repo.loadHome()).remaining, 7000000);
      expect(await db.select(db.periodAllocations).get(), hasLength(3));
    },
  );

  test('onboarding lewat Riverpod: draft → simpan → periode pertama', () async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(isSetUpProvider.future), isFalse);
    container.read(onboardingProvider.notifier)
      ..setAmount(5000000)
      ..setPayday(1)
      ..setAutoAdd(false)
      ..setTemplate(PocketTemplates.pejuangNabung);
    await container.read(onboardingProvider.notifier).finish(opening: 2000000);

    expect(await container.read(isSetUpProvider.future), isTrue);
    final info = await repo.loadPayday();
    // Periode pertama dibagi dari uang user sekarang (layar 42), bukan gaji,
    // juga saat "tambah otomatis" mati. Tidak ada layar "Gajian masuk!".
    expect(info.salary, 2000000);
    expect(info.celebrated, isTrue);
    expect(info.start, DateTime(2026, 9, 1));
    expect(info.allocations.map((a) => a.$1.name), [
      'Kebutuhan',
      'Tabungan',
      'Self-reward',
    ]);
    expect(info.allocations.map((a) => a.$2), [900000, 700000, 400000]);
    final home = await repo.loadHome();
    expect(home.remaining, 2000000);
    expect(home.opening, 2000000);
    // Pengaturan gaji tetap 5 juta untuk gajian berikutnya.
    expect(home.salary, 0);
    expect((await db.select(db.salarySettings).getSingle()).netSalary, 5000000);
  });
}
