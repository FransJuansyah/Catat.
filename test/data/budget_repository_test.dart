import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/data/seed/demo_seed.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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
    now = DateTime(2026, 9, 24, 10);
    repo = BudgetRepository(db, () => now);
  });
  tearDown(() => db.close());

  Future<void> setupKlasik() => repo.setupBudget(
    userName: 'Frans',
    netSalary: 6500000,
    payday: 25,
    template: PocketTemplates.klasik,
  );

  Future<String> pocketId(PocketType type) async =>
      (await db.select(db.pockets).get()).firstWhere((p) => p.type == type).id;

  test('periode dibuat sekali saja walau dipanggil berkali-kali', () async {
    await setupKlasik();
    final a = await repo.ensureCurrentPeriod();
    final b = await repo.ensureCurrentPeriod();
    expect(a.id, b.id);
    expect(await db.select(db.periods).get(), hasLength(1));
    expect(await db.select(db.periodAllocations).get(), hasLength(3));
    expect(a.startDate, DateTime(2026, 8, 25));
  });

  test(
    'gajian berikutnya otomatis membuat periode baru dengan jatah baru',
    () async {
      await setupKlasik();
      await repo.ensureCurrentPeriod();
      now = DateTime(2026, 9, 25, 8);
      final next = await repo.ensureCurrentPeriod();
      expect(next.startDate, DateTime(2026, 9, 25));
      expect(await db.select(db.periods).get(), hasLength(2));
      final summary = await repo.loadHome();
      expect(summary.remaining, 6500000);
    },
  );

  test('pengeluaran mengurangi sisa kantong yang tepat', () async {
    await setupKlasik();
    await repo.addExpense(
      pocketId: await pocketId(PocketType.wajib),
      amount: 52000,
      title: 'Indomaret',
    );
    final home = await repo.loadHome();
    final wajib = home.pockets.firstWhere((p) => p.type == PocketType.wajib);
    expect(wajib.balance.remaining, 3250000 - 52000);
    expect(home.remaining, 6500000 - 52000);
  });

  test('pengeluaran yang dihapus tidak dihitung', () async {
    await setupKlasik();
    final id = await repo.addExpense(
      pocketId: await pocketId(PocketType.keinginan),
      amount: 25000,
      title: 'Kopi',
    );
    await repo.deleteExpense(id);
    expect((await repo.loadHome()).remaining, 6500000);
  });

  test('nominal 0 atau negatif ditolak', () async {
    await setupKlasik();
    final id = await pocketId(PocketType.wajib);
    expect(
      () => repo.addExpense(pocketId: id, amount: 0, title: 'x'),
      throwsArgumentError,
    );
  });

  test('tanggal di luar periode tercatat ditolak', () async {
    await setupKlasik();
    final id = await pocketId(PocketType.wajib);
    expect(
      () => repo.addExpense(
        pocketId: id,
        amount: 1000,
        title: 'x',
        occurredAt: DateTime(2026, 1, 1),
      ),
      throwsStateError,
    );
  });

  test('watchHome ikut ter-update setelah pengeluaran baru', () async {
    await setupKlasik();
    final stream = repo.watchHome();
    final values = <int>[];
    final sub = stream.listen((s) => values.add(s.remaining));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.addExpense(
      pocketId: await pocketId(PocketType.wajib),
      amount: 100000,
      title: 'x',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(values.first, 6500000);
    expect(values.last, 6400000);
  });

  test(
    'data contoh menghasilkan angka persis seperti desain Beranda',
    () async {
      await DemoSeed(repo, db, () => now).seedIfEmpty();
      final home = await repo.loadHome();
      expect(home.userName, 'Frans');
      expect(home.remaining, 2180000);
      expect(home.daysToPayday, 1);
      expect(home.onTrack, isTrue);
      final byType = {
        for (final p in home.pockets) p.type: p.balance.remaining,
      };
      expect(byType, {
        PocketType.wajib: 450000,
        PocketType.darurat: 1300000,
        PocketType.keinginan: 430000,
      });
      // Tidak menggandakan data jika dipanggil lagi.
      await DemoSeed(repo, db, () => now).seedIfEmpty();
      expect((await repo.loadHome()).remaining, 2180000);
    },
  );
}
