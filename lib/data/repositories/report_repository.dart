import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/report.dart';
import '../../domain/types.dart';
import '../../domain/views.dart';
import '../local/database.dart';

/// Laporan & bahan export (layar 14, 07). Hanya membaca data.
///
/// Rentang laporan = bulan kalender. Pemasukan otomatis (gaji / uang jajan)
/// dihitung di bulan periodenya dimulai, sama seperti di Catatan.
class ReportRepository {
  ReportRepository(this._db, this._now);

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Bulan-bulan yang punya data, terbaru dulu (pilihan bulan layar 14).
  Future<List<DateTime>> availableMonths() async {
    final now = _now();
    final current = DateTime(now.year, now.month);
    DateTime? first;
    void consider(DateTime? d) {
      if (d != null && (first == null || d.isBefore(first!))) first = d;
    }

    final p = _db.periods;
    final minPeriod = p.startDate.min();
    consider(
      (await (_db.selectOnly(p)
                ..addColumns([minPeriod])
                ..where(p.deletedAt.isNull()))
              .getSingle())
          .read(minPeriod),
    );
    final e = _db.expenses;
    final minExpense = e.occurredAt.min();
    consider(
      (await (_db.selectOnly(e)
                ..addColumns([minExpense])
                ..where(e.deletedAt.isNull()))
              .getSingle())
          .read(minExpense),
    );
    final i = _db.incomes;
    final minIncome = i.occurredAt.min();
    consider(
      (await (_db.selectOnly(i)
                ..addColumns([minIncome])
                ..where(i.deletedAt.isNull()))
              .getSingle())
          .read(minIncome),
    );
    final start = first == null ? current : DateTime(first!.year, first!.month);
    return [
      for (
        var m = current;
        !m.isBefore(start);
        m = DateTime(m.year, m.month - 1)
      )
        m,
    ];
  }

  Future<ReportData> load(ReportRange range) async {
    final settings =
        await (_db.select(_db.salarySettings)
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    final mode = settings?.incomeMode ?? IncomeMode.salary;
    final allPockets = await (_db.select(
      _db.pockets,
    )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
    final refs = {
      for (final p in allPockets)
        p.id: PocketRef(
          id: p.id,
          type: p.type,
          name: p.name,
          iconKey: p.iconKey,
          color: p.color,
        ),
    };

    // Pengeluaran + item struk.
    final expenseRows =
        await (_db.select(_db.expenses)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.occurredAt.isBiggerOrEqualValue(range.start) &
                    t.occurredAt.isSmallerThanValue(range.end),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
            .get();
    final itemRows = expenseRows.isEmpty
        ? const <ExpenseItem>[]
        : await (_db.select(_db.expenseItems)..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.expenseId.isIn(expenseRows.map((e) => e.id)),
              ))
              .get();
    final itemsOf = <String, List<ExpenseLine>>{};
    for (final it in itemRows) {
      (itemsOf[it.expenseId] ??= []).add(
        ExpenseLine(it.name, it.qty, it.price),
      );
    }
    final expenses = [
      for (final e in expenseRows)
        if (refs[e.pocketId] case final pocket?)
          ReportExpense(
            occurredAt: e.occurredAt,
            title: e.title,
            pocket: pocket,
            amount: e.amount,
            source: e.source,
            merchant: e.merchant,
            note: e.note,
            photoPath: e.photoPath,
            items: itemsOf[e.id] ?? const [],
          ),
    ];

    // Pemasukan otomatis (awal periode) + pemasukan yang ditambah user.
    final periods =
        await (_db.select(_db.periods)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.startDate.isBiggerOrEqualValue(range.start) &
                  t.startDate.isSmallerThanValue(range.end),
            ))
            .get();
    final incomeRows =
        await (_db.select(_db.incomes)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.occurredAt.isBiggerOrEqualValue(range.start) &
                  t.occurredAt.isSmallerThanValue(range.end),
            ))
            .get();
    final autoTitle = mode == IncomeMode.allowance
        ? 'Uang jajan masuk'
        : 'Gajian';
    final incomes = [
      for (final p in periods)
        // Periode pertama dibagi dari saldo awal (layar 42), bukan gaji.
        if ((p.opening ?? p.salary) > 0)
          IncomeEntry(
            id: p.id,
            title: p.opening != null ? 'Saldo awal' : autoTitle,
            amount: p.opening ?? p.salary,
            occurredAt: p.startDate,
            auto: true,
          ),
      for (final i in incomeRows)
        IncomeEntry(
          id: i.id,
          title: i.title,
          amount: i.amount,
          occurredAt: i.occurredAt,
        ),
    ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    // Jatah tiap kantong selama rentang.
    final budget = <String, int>{};
    if (periods.isNotEmpty) {
      final allocs =
          await (_db.select(_db.periodAllocations)..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.periodId.isIn(periods.map((p) => p.id)),
              ))
              .get();
      for (final a in allocs) {
        budget[a.pocketId] = (budget[a.pocketId] ?? 0) + a.amount;
      }
    }
    if (incomeRows.isNotEmpty) {
      final allocs =
          await (_db.select(_db.incomeAllocations)..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.incomeId.isIn(incomeRows.map((i) => i.id)),
              ))
              .get();
      for (final a in allocs) {
        budget[a.pocketId] = (budget[a.pocketId] ?? 0) + a.amount;
      }
    }
    // Pindah saldo, aturannya sama dengan saldo di Beranda: keluar dihitung
    // di periode asal, masuk di periode tujuan (sisa yang pindah ke periode
    // baru).
    if (periods.isNotEmpty) {
      final periodIds = {for (final p in periods) p.id};
      final transfers = await (_db.select(
        _db.transfers,
      )..where((t) => t.deletedAt.isNull())).get();
      for (final t in transfers) {
        if (periodIds.contains(t.periodId)) {
          budget[t.fromPocketId] = (budget[t.fromPocketId] ?? 0) - t.amount;
        }
        if (periodIds.contains(t.toPeriodId ?? t.periodId)) {
          budget[t.toPocketId] = (budget[t.toPocketId] ?? 0) + t.amount;
        }
      }
    }
    final spent = <String, int>{};
    for (final e in expenses) {
      spent[e.pocket.id] = (spent[e.pocket.id] ?? 0) + e.amount;
    }

    final pockets = [
      for (final p in allPockets)
        if (p.deletedAt == null || (spent[p.id] ?? 0) > 0)
          PocketReport(
            pocket: refs[p.id]!,
            spent: spent[p.id] ?? 0,
            budget: budget[p.id] ?? 0,
          ),
    ];

    final months = [
      for (final m in range.months)
        MonthTotal(
          m,
          incomes
              .where((i) => _sameMonth(i.occurredAt, m))
              .fold<int>(0, (s, i) => s + i.amount),
          expenses
              .where((e) => _sameMonth(e.occurredAt, m))
              .fold<int>(0, (s, e) => s + e.amount),
        ),
    ];

    return ReportData(
      range: range,
      mode: mode,
      pockets: pockets,
      months: months,
      expenses: expenses,
      incomes: incomes,
    );
  }

  /// Laporan satu bulan + insight dibanding bulan sebelumnya (layar 14).
  Future<MonthReport> loadMonth(DateTime month) async {
    final range = ReportRange.of(ReportSpan.month, month);
    final current = await load(range);
    final previous = await load(
      ReportRange.of(
        ReportSpan.month,
        DateTime(range.start.year, range.start.month - 1),
      ),
    );
    return MonthReport(
      data: current,
      insight: buildInsight(current, previous),
      months: await availableMonths(),
    );
  }

  Stream<MonthReport> watchMonth(DateTime month) {
    final controller = StreamController<MonthReport>();
    StreamSubscription<void>? updates;
    var queue = Future<void>.value();
    void refresh() {
      queue = queue.then((_) async {
        try {
          final value = await loadMonth(month);
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
      ..onCancel = () {
        unawaited(updates?.cancel());
        unawaited(controller.close());
      };
    return controller.stream;
  }

  static bool _sameMonth(DateTime d, DateTime m) =>
      d.year == m.year && d.month == m.month;
}

/// Data layar Laporan (14).
class MonthReport {
  const MonthReport({
    required this.data,
    required this.insight,
    required this.months,
  });

  final ReportData data;
  final ReportInsight? insight;

  /// Pilihan bulan (terbaru dulu).
  final List<DateTime> months;
}
