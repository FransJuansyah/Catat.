import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/bill_repository.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/bills.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late BudgetRepository budget;
  late BillRepository bills;
  var now = DateTime(2026, 10, 9, 10);

  setUp(() async {
    now = DateTime(2026, 10, 9, 10);
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    budget = BudgetRepository(db, () => now);
    bills = BillRepository(db, budget, () => now);
    await budget.setupBudget(
      netSalary: 6500000,
      payday: 25,
      template: PocketTemplates.klasik,
    );
  });
  tearDown(() => db.close());

  Future<String> pocketOf(PocketType type) async => (await (db.select(
    db.pockets,
  )..where((t) => t.type.equalsValue(type))).getSingle()).id;

  test('tambah cicilan, bayar → pengeluaran tercatat & maju sebulan', () async {
    final darurat = await pocketOf(PocketType.darurat);
    final id = await bills.addBill(
      name: 'Cicilan HP',
      iconKey: 'phone',
      amount: 500000,
      dueDay: 10,
      kind: BillKind.cicilan,
      remaining: 8,
      pocketId: darurat,
    );
    var hp = (await bills.loadBill(id))!;
    expect(hp.nextDue, DateTime(2026, 10, 10));
    expect(monthLabel(hp.lastMonth!), 'Mei 2027');

    final expenseId = await bills.payBill(id);
    final e = await (db.select(
      db.expenses,
    )..where((t) => t.id.equals(expenseId!))).getSingle();
    expect(e.amount, 500000);
    expect(e.title, 'Cicilan HP');
    expect(e.pocketId, darurat);

    hp = (await bills.loadBill(id))!;
    expect(hp.remaining, 7);
    expect(hp.nextDue, DateTime(2026, 11, 10));
    expect(summarizeBills([hp], now).done.single.id, id);
  });

  test('kantong tagihan dihapus → bayar dari kantong Wajib', () async {
    final id = await bills.addBill(
      name: 'Kos',
      iconKey: 'house',
      amount: 1500000,
      dueDay: 1,
      kind: BillKind.rutin,
      pocketId: 'kantong-hilang',
    );
    final expenseId = await bills.payBill(id);
    final e = await (db.select(
      db.expenses,
    )..where((t) => t.id.equals(expenseId!))).getSingle();
    expect(e.pocketId, await pocketOf(PocketType.wajib));
  });

  test('cicilan terakhir dibayar → selesai, tidak bisa dibayar lagi', () async {
    final id = await bills.addBill(
      name: 'Pinjol',
      iconKey: 'card',
      amount: 100000,
      dueDay: 20,
      kind: BillKind.cicilan,
      remaining: 1,
    );
    expect(await bills.payBill(id), isNotNull);
    expect((await bills.loadBill(id))!.finished, isTrue);
    expect(await bills.payBill(id), isNull);
  });

  test('ubah & hapus; ikut antrian sinkron', () async {
    final id = await bills.addBill(
      name: 'Spotify',
      iconKey: 'tv',
      amount: 55000,
      dueDay: 3,
      kind: BillKind.rutin,
    );
    await bills.updateBill(
      id,
      name: 'Spotify Duo',
      iconKey: 'tv',
      amount: 75000,
      dueDay: 12,
      kind: BillKind.rutin,
    );
    final b = (await bills.loadBill(id))!;
    expect(b.name, 'Spotify Duo');
    // Belum pernah dibayar → bulan mulai ikut tanggal baru (12 Okt, belum lewat).
    expect(b.nextDue, DateTime(2026, 10, 12));
    final queued = await (db.select(
      db.syncOutbox,
    )..where((t) => t.tableName_.equals('bills'))).get();
    expect(queued.map((r) => r.rowId), [id]);

    await bills.deleteBill(id);
    expect(await bills.loadBills(), isEmpty);
  });
}
