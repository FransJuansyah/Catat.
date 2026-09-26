import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/allocation.dart';
import '../../domain/expense_icon.dart';
import '../../domain/home_summary.dart';
import '../../domain/pay_period.dart';
import '../../domain/pocket_balance.dart';
import '../../domain/templates.dart';
import '../../domain/types.dart';
import '../../domain/views.dart';
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
    String userName = '',
    required int netSalary,
    required int payday,
    required PocketTemplate template,
    bool autoAdd = true,
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
              autoAdd: Value(autoAdd),
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

      // "Tambah otomatis" mati → periode dibuat dengan gaji 0, user mengisi
      // sendiri lewat layar Gajian Masuk (setPeriodSalary).
      final salary = settings.autoAdd ? settings.netSalary : 0;
      final pockets = await _activePockets();
      final amounts = allocateAll(salary, pockets.map(_ruleOf).toList());
      final periodId = _newId();
      await _db
          .into(_db.periods)
          .insert(
            PeriodsCompanion.insert(
              id: periodId,
              startDate: period.start,
              endDate: period.end,
              salary: salary,
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

  /// Gaji periode berjalan & pembagiannya (layar 18).
  Future<PaydayInfo> loadPayday() async {
    final period = await ensureCurrentPeriod();
    final allocations = await (_db.select(
      _db.periodAllocations,
    )..where((t) => t.periodId.equals(period.id) & t.deletedAt.isNull())).get();
    final refs = await _pocketRefs();
    final pockets = await _activePockets();
    final amountOf = {for (final a in allocations) a.pocketId: a.amount};
    return PaydayInfo(
      periodId: period.id,
      start: dateOnly(period.startDate),
      salary: period.salary,
      celebrated: period.celebrated,
      allocations: [
        for (final p in pockets)
          if (refs[p.id] case final ref?) (ref, amountOf[p.id] ?? 0),
      ],
    );
  }

  Stream<PaydayInfo> watchPayday() => _watch(loadPayday);

  Future<void> markCelebrated(String periodId) async {
    await (_db.update(_db.periods)..where((t) => t.id.equals(periodId))).write(
      PeriodsCompanion(celebrated: const Value(true), updatedAt: Value(_now())),
    );
  }

  /// Isi/ubah gaji satu periode lalu bagi ulang ke kantong.
  Future<void> setPeriodSalary(String periodId, int salary) {
    if (salary < 0) throw ArgumentError.value(salary, 'salary');
    return _db.transaction(() async {
      final now = _now();
      await (_db.update(
        _db.periods,
      )..where((t) => t.id.equals(periodId))).write(
        PeriodsCompanion(salary: Value(salary), updatedAt: Value(now)),
      );
      final pockets = await _activePockets();
      final amounts = allocateAll(salary, pockets.map(_ruleOf).toList());
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
              onConflict: DoUpdate(
                (_) => PeriodAllocationsCompanion(
                  amount: Value(amounts[p.id]!),
                  updatedAt: Value(now),
                ),
                target: [
                  _db.periodAllocations.periodId,
                  _db.periodAllocations.pocketId,
                ],
              ),
            );
      }
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

  /// Ubah pengeluaran (layar 11 mode edit). Item struk tidak diubah.
  Future<void> updateExpense(
    String id, {
    required String pocketId,
    required int amount,
    required String title,
    required DateTime occurredAt,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'harus lebih dari 0');
    }
    return _db.transaction(() async {
      final period = await _periodFor(occurredAt);
      await (_db.update(_db.expenses)..where((t) => t.id.equals(id))).write(
        ExpensesCompanion(
          pocketId: Value(pocketId),
          periodId: Value(period.id),
          amount: Value(amount),
          title: Value(title),
          occurredAt: Value(occurredAt),
          updatedAt: Value(_now()),
        ),
      );
    });
  }

  // ----------------------------------------------------------------- home

  Future<HomeSummary> loadHome() async {
    final period = await ensureCurrentPeriod();
    final profile =
        await (_db.select(_db.profiles)
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    final payPeriod = PayPeriod(
      dateOnly(period.startDate),
      dateOnly(period.endDate),
    );
    final today = _now();
    final views = await _pocketViews(period.id);
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
  Stream<HomeSummary> watchHome() => _watch(loadHome);

  // ------------------------------------------------------------ catatan

  /// Pengeluaran di satu tanggal, urut dari pagi (layar 06).
  Future<DayNotes> loadDay(DateTime day) async {
    final start = dateOnly(day);
    final end = DateTime(start.year, start.month, start.day + 1);
    final rows =
        await (_db.select(_db.expenses)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.occurredAt.isBiggerOrEqualValue(start) &
                    t.occurredAt.isSmallerThanValue(end),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
            .get();
    return DayNotes(start, await _entries(rows));
  }

  Stream<DayNotes> watchDay(DateTime day) => _watch(() => loadDay(day));

  /// Titik warna kantong per tanggal + tanggal gajian (layar 06).
  Future<CalendarMonth> loadMonth(int year, int month) async {
    final first = DateTime(year, month);
    final next = DateTime(year, month + 1);
    final rows =
        await (_db.select(_db.expenses)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.occurredAt.isBiggerOrEqualValue(first) &
                  t.occurredAt.isSmallerThanValue(next),
            ))
            .get();
    final pockets = await _allPockets();
    final order = {for (final p in pockets) p.id: p.sortOrder};
    final colorOf = {for (final p in pockets) p.id: p.color};

    final byDay = <int, Set<String>>{};
    for (final r in rows) {
      byDay.putIfAbsent(r.occurredAt.day, () => {}).add(r.pocketId);
    }
    final dots = {
      for (final MapEntry(key: day, value: ids) in byDay.entries)
        day:
            (ids.toList()
                  ..sort((a, b) => (order[a] ?? 0).compareTo(order[b] ?? 0)))
                .map((id) => colorOf[id] ?? 0xFFA1A1AA)
                .toList(),
    };
    final settings = await _salarySettings();
    return CalendarMonth(
      year: year,
      month: month,
      dots: dots,
      paydayDay: settings == null
          ? null
          : paydayIn(year, month, settings.payday).day,
    );
  }

  Stream<CalendarMonth> watchMonth(int year, int month) =>
      _watch(() => loadMonth(year, month));

  // -------------------------------------------------------------- detail

  /// Detail satu pengeluaran, `null` jika tidak ada / sudah dihapus (layar 13).
  Future<ExpenseDetail?> loadExpense(String id) async {
    final row = await (_db.select(
      _db.expenses,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    final items = await (_db.select(
      _db.expenseItems,
    )..where((t) => t.expenseId.equals(id) & t.deletedAt.isNull())).get();
    return ExpenseDetail(
      entry: (await _entries([row])).single,
      items: [for (final i in items) ExpenseLine(i.name, i.qty, i.price)],
      merchant: row.merchant,
      photoPath: row.photoPath,
      note: row.note,
    );
  }

  Stream<ExpenseDetail?> watchExpense(String id) =>
      _watch(() => loadExpense(id));

  /// Kantong di periode berjalan + riwayatnya, terbaru dulu (layar 12).
  Future<PocketDetail?> loadPocket(String pocketId) async {
    final period = await ensureCurrentPeriod();
    final views = await _pocketViews(period.id);
    final view = views.where((v) => v.id == pocketId).firstOrNull;
    if (view == null) return null;
    final pocketRow = await (_db.select(
      _db.pockets,
    )..where((t) => t.id.equals(pocketId))).getSingle();
    final rows =
        await (_db.select(_db.expenses)
              ..where(
                (t) =>
                    t.pocketId.equals(pocketId) &
                    t.periodId.equals(period.id) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
            .get();
    final payPeriod = PayPeriod(
      dateOnly(period.startDate),
      dateOnly(period.endDate),
    );
    return PocketDetail(
      pocket: view,
      expenses: await _entries(rows),
      daysToPayday: payPeriod.daysUntilNextPayday(_now()),
      lowThresholdPercent: pocketRow.lowThresholdPercent,
    );
  }

  Stream<PocketDetail?> watchPocket(String pocketId) =>
      _watch(() => loadPocket(pocketId));

  // ---------------------------------------------------------- streaming

  /// Jalankan [load] ulang setiap ada perubahan data, berurutan supaya hasil
  /// lama tidak menimpa hasil baru.
  Stream<T> _watch<T>(Future<T> Function() load) {
    final controller = StreamController<T>();
    StreamSubscription<void>? updates;
    var queue = Future<void>.value();

    void refresh() {
      queue = queue.then((_) async {
        try {
          final value = await load();
          if (!controller.isClosed) controller.add(value);
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

  /// Termasuk kantong yang sudah dihapus, agar riwayat lama tetap bernama.
  Future<List<PocketRow>> _allPockets() => (_db.select(
    _db.pockets,
  )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  Future<List<PocketView>> _pocketViews(String periodId) async {
    final pockets = await _activePockets();
    final balances = await _balances(periodId);
    return [
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
  }

  Future<Map<String, PocketRef>> _pocketRefs() async => {
    for (final p in await _allPockets())
      p.id: PocketRef(
        id: p.id,
        type: p.type,
        name: p.name,
        iconKey: p.iconKey,
        color: p.color,
      ),
  };

  Future<List<ExpenseEntry>> _entries(List<ExpenseRow> rows) async {
    if (rows.isEmpty) return const [];
    final refs = await _pocketRefs();
    return [
      for (final r in rows)
        if (refs[r.pocketId] case final pocket?)
          ExpenseEntry(
            id: r.id,
            title: r.title,
            amount: r.amount,
            occurredAt: r.occurredAt,
            source: r.source,
            pocket: pocket,
            iconKey: guessExpenseIcon(r.title, fallback: pocket.iconKey),
          ),
    ];
  }

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
