import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/allocation.dart';
import '../../domain/home_summary.dart';
import '../../domain/pay_period.dart';
import '../../domain/pocket_balance.dart';
import '../../domain/templates.dart';
import '../../domain/types.dart';
import '../local/database.dart';

class ExpenseItemInput {
  const ExpenseItemInput(this.name, this.price, {this.qty = 1});
  final String name;
  final int price;
  final int qty;
}

/// Satu pintu akses data gaji, kantong, periode, dan pengeluaran.
/// UI tidak boleh menyentuh [AppDatabase] langsung.
class BudgetRepository {
  BudgetRepository(this._db, this._now, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _now;
  final Uuid _uuid;

  String _newId() => _uuid.v4();

  // ---------------------------------------------------------------- setup

  Future<bool> isSetUp() async => await _salarySettings() != null;

  /// Simpan profil, gaji, dan kantong dari template (dipakai onboarding, layar 02 & 19).
  Future<void> setupBudget({
    required String userName,
    required int netSalary,
    required int payday,
    required PocketTemplate template,
  }) {
    if (netSalary < 0) throw ArgumentError.value(netSalary, 'netSalary');
    if (payday < 1 || payday > 31) throw ArgumentError.value(payday, 'payday');
    return _db.transaction(() async {
      await _db
          .into(_db.profiles)
          .insert(ProfilesCompanion.insert(id: _newId(), name: userName));
      await _db
          .into(_db.salarySettings)
          .insert(
            SalarySettingsCompanion.insert(
              id: _newId(),
              netSalary: netSalary,
              payday: payday,
            ),
          );
      for (final (i, p) in template.pockets.indexed) {
        await _db
            .into(_db.pockets)
            .insert(
              PocketsCompanion.insert(
                id: _newId(),
                type: p.type,
                name: p.name,
                iconKey: p.iconKey,
                color: p.color,
                sortOrder: Value(i),
                percent: Value(p.percent),
              ),
            );
      }
    });
  }

  // --------------------------------------------------------------- period

  /// Periode gaji yang sedang berjalan. Dibuat sekali per siklus (idempoten):
  /// aman dipanggil berkali-kali, juga saat offline.
  Future<PeriodRow> ensureCurrentPeriod() {
    return _db.transaction(() async {
      final settings = await _salarySettings();
      if (settings == null) throw StateError('Gaji belum diatur');
      final period = PayPeriod.containing(_now(), settings.payday);

      final existing =
          await (_db.select(_db.periods)..where(
                (t) => t.startDate.equals(period.start) & t.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (existing != null) return existing;

      final pockets = await _activePockets();
      final amounts = allocateAll(
        settings.netSalary,
        pockets.map(_ruleOf).toList(),
      );
      final periodId = _newId();
      await _db
          .into(_db.periods)
          .insert(
            PeriodsCompanion.insert(
              id: periodId,
              startDate: period.start,
              endDate: period.end,
              salary: settings.netSalary,
            ),
          );
      for (final p in pockets) {
        await _db
            .into(_db.periodAllocations)
            .insert(
              PeriodAllocationsCompanion.insert(
                id: _newId(),
                periodId: periodId,
                pocketId: p.id,
                amount: amounts[p.id]!,
              ),
            );
      }
      return (_db.select(
        _db.periods,
      )..where((t) => t.id.equals(periodId))).getSingle();
    });
  }

  // -------------------------------------------------------------- expense

  /// Catat pengeluaran. Tanggal harus berada di periode yang sudah tercatat
  /// atau periode berjalan.
  Future<String> addExpense({
    required String pocketId,
    required int amount,
    required String title,
    DateTime? occurredAt,
    ExpenseSource source = ExpenseSource.manual,
    String? merchant,
    String? note,
    List<ExpenseItemInput> items = const [],
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'harus lebih dari 0');
    }
    final when = occurredAt ?? _now();
    return _db.transaction(() async {
      final period = await _periodFor(when);
      final id = _newId();
      await _db
          .into(_db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: id,
              pocketId: pocketId,
              periodId: period.id,
              amount: amount,
              title: title,
              occurredAt: when,
              source: source,
              merchant: Value(merchant),
              note: Value(note),
            ),
          );
      for (final item in items) {
        await _db
            .into(_db.expenseItems)
            .insert(
              ExpenseItemsCompanion.insert(
                id: _newId(),
                expenseId: id,
                name: item.name,
                qty: Value(item.qty),
                price: item.price,
              ),
            );
      }
      return id;
    });
  }

  /// Hapus lunak (tetap tersimpan untuk sinkronisasi).
  Future<void> deleteExpense(String id) async {
    final now = _now();
    await (_db.update(_db.expenses)..where((t) => t.id.equals(id))).write(
      ExpensesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // ----------------------------------------------------------------- home

  Future<HomeSummary> loadHome() async {
    final period = await ensureCurrentPeriod();
    final profile =
        await (_db.select(_db.profiles)
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    final pockets = await _activePockets();
    final balances = await _balances(period.id);

    final payPeriod = PayPeriod(
      dateOnly(period.startDate),
      dateOnly(period.endDate),
    );
    final today = _now();
    final views = [
      for (final p in pockets)
        PocketView(
          id: p.id,
          type: p.type,
          name: p.name,
          iconKey: p.iconKey,
          color: p.color,
          balance: balances[p.id] ?? const PocketBalance(allocation: 0),
        ),
    ];
    final budget = views.fold<int>(0, (s, v) => s + v.balance.available);
    final spent = views.fold<int>(0, (s, v) => s + v.balance.spent);

    return HomeSummary(
      userName: profile?.name ?? '',
      salary: period.salary,
      pockets: views,
      daysToPayday: payPeriod.daysUntilNextPayday(today),
      onTrack: isOnTrack(
        spent: spent,
        budget: budget,
        elapsedRatio: payPeriod.elapsedRatio(today),
      ),
    );
  }

  /// Beranda yang otomatis ter-update setiap ada perubahan data.
  Stream<HomeSummary> watchHome() {
    final controller = StreamController<HomeSummary>();
    StreamSubscription<void>? updates;
    var queue = Future<void>.value();

    // Diproses berurutan supaya hasil lama tidak menimpa hasil baru.
    void refresh() {
      queue = queue.then((_) async {
        try {
          final summary = await loadHome();
          if (!controller.isClosed) controller.add(summary);
        } catch (e, st) {
          if (!controller.isClosed) controller.addError(e, st);
        }
      });
    }

    controller
      ..onListen = () {
        refresh();
        updates = _db.tableUpdates().listen((_) => refresh());
      }
      // Jangan menunggu pembatalan stream drift: bisa menggantung saat DB ditutup.
      ..onCancel = () {
        unawaited(updates?.cancel());
        unawaited(controller.close());
      };
    return controller.stream;
  }

  // -------------------------------------------------------------- helpers

  Future<SalarySetting?> _salarySettings() =>
      (_db.select(_db.salarySettings)
            ..where((t) => t.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  Future<List<PocketRow>> _activePockets() =>
      (_db.select(_db.pockets)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  PocketRule _ruleOf(PocketRow p) => PocketRule(
    pocketId: p.id,
    mode: p.mode,
    percent: p.percent,
    nominal: p.nominal,
    rangeMin: p.rangeMin,
    rangeMax: p.rangeMax,
  );

  Future<PeriodRow> _periodFor(DateTime when) async {
    final day = dateOnly(when);
    final found =
        await (_db.select(_db.periods)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.startDate.isSmallerOrEqualValue(day) &
                  t.endDate.isBiggerOrEqualValue(day),
            ))
            .getSingleOrNull();
    if (found != null) return found;
    final current = await ensureCurrentPeriod();
    final range = PayPeriod(
      dateOnly(current.startDate),
      dateOnly(current.endDate),
    );
    if (range.contains(when)) return current;
    throw StateError('Tanggal $day di luar periode gaji yang tercatat');
  }

  Future<Map<String, PocketBalance>> _balances(String periodId) async {
    final allocations = await (_db.select(
      _db.periodAllocations,
    )..where((t) => t.periodId.equals(periodId) & t.deletedAt.isNull())).get();

    final e = _db.expenses;
    final spentSum = e.amount.sum();
    final spentRows =
        await (_db.selectOnly(e)
              ..addColumns([e.pocketId, spentSum])
              ..where(e.periodId.equals(periodId) & e.deletedAt.isNull())
              ..groupBy([e.pocketId]))
            .get();
    final spent = {
      for (final r in spentRows) r.read(e.pocketId)!: r.read(spentSum) ?? 0,
    };

    final t = _db.transfers;
    final amountSum = t.amount.sum();
    Future<Map<String, int>> transferTotals(
      GeneratedColumn<String> byPocket,
    ) async {
      final rows =
          await (_db.selectOnly(t)
                ..addColumns([byPocket, amountSum])
                ..where(t.periodId.equals(periodId) & t.deletedAt.isNull())
                ..groupBy([byPocket]))
              .get();
      return {for (final r in rows) r.read(byPocket)!: r.read(amountSum) ?? 0};
    }

    final incoming = await transferTotals(t.toPocketId);
    final outgoing = await transferTotals(t.fromPocketId);

    return {
      for (final a in allocations)
        a.pocketId: PocketBalance(
          allocation: a.amount,
          spent: spent[a.pocketId] ?? 0,
          transferIn: incoming[a.pocketId] ?? 0,
          transferOut: outgoing[a.pocketId] ?? 0,
        ),
    };
  }
}
