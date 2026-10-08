import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/bills.dart';
import '../../domain/types.dart';
import '../local/database.dart';
import 'budget_repository.dart';

/// Tagihan & cicilan (layar 69–71, 73). Bayar = catat pengeluaran di kantong
/// tagihan + maju ke bulan berikutnya.
class BillRepository {
  BillRepository(this._db, this._budget, this._now, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final BudgetRepository _budget;
  final DateTime Function() _now;
  final Uuid _uuid;

  static Bill toBill(BillRow r) => Bill(
    id: r.id,
    name: r.name,
    iconKey: r.iconKey,
    amount: r.amount,
    dueDay: r.dueDay,
    kind: r.kind,
    remaining: r.remaining,
    pocketId: r.pocketId,
    remind: r.remind,
    startMonth: r.startMonth,
    paidThrough: r.paidThrough,
  );

  SimpleSelectStatement<$BillsTable, BillRow> _active() => _db.select(_db.bills)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm(expression: t.dueDay)]);

  Future<List<Bill>> loadBills() async =>
      (await _active().get()).map(toBill).toList();

  Stream<List<Bill>> watchBills() =>
      _active().watch().map((rows) => rows.map(toBill).toList());

  Future<Bill?> loadBill(String id) async {
    final row = await (_db.select(
      _db.bills,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : toBill(row);
  }

  Future<String> addBill({
    required String name,
    required String iconKey,
    required int amount,
    required int dueDay,
    required BillKind kind,
    int? remaining,
    String? pocketId,
    bool remind = true,
  }) async {
    _check(amount, dueDay, kind, remaining);
    final id = _uuid.v4();
    final start = firstDueMonth(dueDay, _now());
    await _db
        .into(_db.bills)
        .insert(
          BillsCompanion.insert(
            id: id,
            name: name.trim(),
            iconKey: iconKey,
            amount: amount,
            dueDay: dueDay,
            kind: kind,
            remaining: Value(kind == BillKind.cicilan ? remaining : null),
            pocketId: Value(pocketId),
            remind: Value(remind),
            startMonth: start,
            paidThrough: start - 1,
          ),
        );
    return id;
  }

  /// Ubah tagihan. Riwayat bayar tetap; tagihan yang belum pernah dibayar
  /// ikut pindah bulan mulainya kalau tanggalnya diganti.
  Future<void> updateBill(
    String id, {
    required String name,
    required String iconKey,
    required int amount,
    required int dueDay,
    required BillKind kind,
    int? remaining,
    String? pocketId,
    bool remind = true,
  }) async {
    _check(amount, dueDay, kind, remaining);
    final old = await loadBill(id);
    if (old == null) return;
    final neverPaid = old.paidThrough < old.startMonth;
    final start = neverPaid ? firstDueMonth(dueDay, _now()) : old.startMonth;
    await (_db.update(_db.bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        name: Value(name.trim()),
        iconKey: Value(iconKey),
        amount: Value(amount),
        dueDay: Value(dueDay),
        kind: Value(kind),
        remaining: Value(kind == BillKind.cicilan ? remaining : null),
        pocketId: Value(pocketId),
        remind: Value(remind),
        startMonth: Value(start),
        paidThrough: Value(neverPaid ? start - 1 : old.paidThrough),
        updatedAt: Value(_now()),
      ),
    );
  }

  Future<void> deleteBill(String id) async {
    final now = _now();
    await (_db.update(_db.bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// "Udah bayar": catat pengeluaran (judul = nama tagihan) di kantongnya,
  /// lalu tagihan maju ke bulan berikutnya. Mengembalikan id pengeluaran.
  Future<String?> payBill(String id) {
    return _db.transaction(() async {
      final b = await loadBill(id);
      if (b == null || b.finished) return null;
      final pocketId = await _pocketFor(b.pocketId);
      final expenseId = await _budget.addExpense(
        pocketId: pocketId,
        amount: b.amount,
        title: b.name,
        source: ExpenseSource.manual,
      );
      await (_db.update(_db.bills)..where((t) => t.id.equals(id))).write(
        BillsCompanion(
          paidThrough: Value(b.nextMonth),
          remaining: Value(b.remaining == null ? null : b.remaining! - 1),
          updatedAt: Value(_now()),
        ),
      );
      return expenseId;
    });
  }

  /// Kantong tagihan kalau masih ada; selain itu kantong Wajib pertama.
  Future<String> _pocketFor(String? pocketId) async {
    final pockets = await (_db.select(
      _db.pockets,
    )..where((t) => t.deletedAt.isNull())).get();
    final own = pockets.where((p) => p.id == pocketId).firstOrNull;
    if (own != null) return own.id;
    final wajib = pockets.where((p) => p.type == PocketType.wajib).firstOrNull;
    return (wajib ?? pockets.first).id;
  }

  static void _check(int amount, int dueDay, BillKind kind, int? remaining) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    if (dueDay < 1 || dueDay > 31) throw ArgumentError.value(dueDay, 'dueDay');
    if (kind == BillKind.cicilan && (remaining == null || remaining < 1)) {
      throw ArgumentError.value(remaining, 'remaining');
    }
  }
}
