import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fitur F2: catatan harian, kalender, detail transaksi & kantong, ubah catatan.
void main() {
  late AppDatabase db;
  late DateTime now;
  late BudgetRepository repo;
  late Map<PocketType, String> pocket;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    now = DateTime(2026, 9, 24, 18);
    repo = BudgetRepository(db, () => now);
    await repo.setupBudget(
      userName: 'Frans',
      netSalary: 6500000,
      payday: 25,
      template: PocketTemplates.klasik,
    );
    pocket = {for (final p in await db.select(db.pockets).get()) p.type: p.id};
  });
  tearDown(() => db.close());

  Future<String> spend(
    PocketType t,
    int amount,
    String title,
    DateTime at, {
    ExpenseSource source = ExpenseSource.manual,
    List<ExpenseItemInput> items = const [],
  }) => repo.addExpense(
    pocketId: pocket[t]!,
    amount: amount,
    title: title,
    occurredAt: at,
    source: source,
    items: items,
  );

  test(
    'catatan harian: hanya tanggal itu, urut dari pagi, total benar',
    () async {
      await spend(
        PocketType.keinginan,
        25000,
        'Kopi susu',
        DateTime(2026, 9, 24, 15, 40),
      );
      await spend(
        PocketType.wajib,
        52000,
        'Belanja Indomaret',
        DateTime(2026, 9, 24, 10, 15),
      );
      await spend(
        PocketType.wajib,
        45000,
        'Makan siang',
        DateTime(2026, 9, 24, 12, 30),
      );
      await spend(
        PocketType.wajib,
        150000,
        'Token listrik',
        DateTime(2026, 9, 23, 9),
      );

      final day = await repo.loadDay(DateTime(2026, 9, 24, 23));
      expect(day.items.map((e) => e.title), [
        'Belanja Indomaret',
        'Makan siang',
        'Kopi susu',
      ]);
      expect(day.total, 122000);
      expect(day.items.first.iconKey, 'bag');
      expect(day.items.first.pocket.name, 'Wajib');

      expect((await repo.loadDay(DateTime(2026, 9, 19))).items, isEmpty);
    },
  );

  test('kalender: titik per tanggal urut kantong + tanggal gajian', () async {
    await spend(PocketType.keinginan, 25000, 'Kopi', DateTime(2026, 9, 5, 9));
    await spend(PocketType.wajib, 50000, 'Makan', DateTime(2026, 9, 5, 12));
    await spend(
      PocketType.wajib,
      20000,
      'Makan lagi',
      DateTime(2026, 9, 5, 19),
    );
    await spend(PocketType.darurat, 100000, 'Obat', DateTime(2026, 9, 10, 9));

    final month = await repo.loadMonth(2026, 9);
    expect(month.dots[5], [
      0xFF6D5DFC,
      0xFFFF4F7B,
    ]); // Wajib dulu, lalu Keinginan
    expect(month.dots[10], [0xFF12A36B]);
    expect(month.dots.containsKey(6), isFalse);
    expect(month.paydayDay, 25);

    expect((await repo.loadMonth(2026, 2)).paydayDay, 25);
  });

  test('detail transaksi berisi item struk; null setelah dihapus', () async {
    final id = await spend(
      PocketType.wajib,
      52000,
      'Belanja Indomaret',
      DateTime(2026, 9, 24, 10, 15),
      source: ExpenseSource.scan,
      items: const [
        ExpenseItemInput('Susu UHT 1L', 36000, qty: 2),
        ExpenseItemInput('Roti tawar', 16000),
      ],
    );
    final detail = await repo.loadExpense(id);
    expect(detail!.entry.amount, 52000);
    expect(detail.entry.source, ExpenseSource.scan);
    expect(detail.items.map((i) => (i.name, i.qty, i.price)), [
      ('Susu UHT 1L', 2, 36000),
      ('Roti tawar', 1, 16000),
    ]);

    await repo.deleteExpense(id);
    expect(await repo.loadExpense(id), isNull);
  });

  test('ubah catatan: pindah kantong & nominal, saldo ikut berubah', () async {
    final id = await spend(
      PocketType.wajib,
      50000,
      'Kopi',
      DateTime(2026, 9, 24, 9),
    );
    await repo.updateExpense(
      id,
      pocketId: pocket[PocketType.keinginan]!,
      amount: 30000,
      title: 'Kopi susu',
      occurredAt: DateTime(2026, 9, 23, 9),
    );
    final home = await repo.loadHome();
    int remaining(PocketType t) =>
        home.pockets.firstWhere((p) => p.type == t).balance.remaining;
    expect(remaining(PocketType.wajib), 3250000);
    expect(remaining(PocketType.keinginan), 1950000 - 30000);
    expect((await repo.loadExpense(id))!.entry.title, 'Kopi susu');
    expect(
      () => repo.updateExpense(
        id,
        pocketId: pocket[PocketType.wajib]!,
        amount: 0,
        title: 'x',
        occurredAt: now,
      ),
      throwsArgumentError,
    );
  });

  test(
    'detail kantong: saldo & riwayat periode berjalan, terbaru dulu',
    () async {
      await spend(
        PocketType.wajib,
        1500000,
        'Bayar kos',
        DateTime(2026, 9, 1, 8),
      );
      await spend(
        PocketType.wajib,
        52000,
        'Belanja Indomaret',
        DateTime(2026, 9, 24, 10),
      );
      await spend(
        PocketType.keinginan,
        25000,
        'Kopi',
        DateTime(2026, 9, 24, 11),
      );

      final detail = await repo.loadPocket(pocket[PocketType.wajib]!);
      expect(detail!.pocket.balance.remaining, 3250000 - 1552000);
      expect(detail.expenses.map((e) => e.title), [
        'Belanja Indomaret',
        'Bayar kos',
      ]);
      expect(detail.expenses.last.iconKey, 'house');
      expect(detail.daysToPayday, 1);
      expect(await repo.loadPocket('tidak-ada'), isNull);
    },
  );
}
