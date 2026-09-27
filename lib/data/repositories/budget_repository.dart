import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../domain/allocation.dart';
import '../../domain/expense_icon.dart';
import '../../domain/home_summary.dart';
import '../../domain/income_schedule.dart';
import '../../domain/pay_period.dart';
import '../../domain/pocket_balance.dart';
import '../../domain/pocket_config.dart';
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

/// Satu pintu akses data pemasukan, kantong, periode, dan pengeluaran.
/// UI tidak boleh menyentuh [AppDatabase] langsung.
///
/// Dua cara hitung saldo kantong:
/// - **Per periode** (gaji & uang jajan): jatah periode + pemasukan tambahan
///   di periode itu − pengeluaran periode itu. Reset tiap periode baru.
/// - **Berjalan** (penghasilan tidak tetap): semua pemasukan − semua
///   pengeluaran, tidak pernah di-reset. Periode = bulan kalender, hanya
///   sebagai wadah laporan.
class BudgetRepository {
  BudgetRepository(this._db, this._now, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _now;
  final Uuid _uuid;

  String _newId() => _uuid.v4();

  /// Id tetap untuk baris turunan (periode, jatah, pembagian pemasukan,
  /// rollover): dua HP yang membuatnya offline dapat id yang sama, jadi
  /// tidak dobel setelah sinkron.
  String _keyId(String kind, List<String> parts) =>
      _uuid.v5(Namespace.url.value, 'catat:$kind:${parts.join('|')}');

  // ---------------------------------------------------------------- setup

  Future<bool> isSetUp() async => await _salarySettings() != null;

  /// Simpan profil, pengaturan pemasukan, dan kantong dari template
  /// (onboarding, layar 02/28/29 & 19). [netSalary] = nominal per siklus.
  Future<void> setupBudget({
    String userName = '',
    required int netSalary,
    int payday = 25,
    required PocketTemplate template,
    bool autoAdd = true,
    IncomeMode incomeMode = IncomeMode.salary,
    IncomeFrequency frequency = IncomeFrequency.monthly,
    int weekday = 1,
    int? monthlyEstimate,
    bool incomeReminder = false,
  }) {
    if (netSalary < 0) throw ArgumentError.value(netSalary, 'netSalary');
    if (payday < 1 || payday > 31) throw ArgumentError.value(payday, 'payday');
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError.value(weekday, 'weekday');
    }
    return _db.transaction(() async {
      // Sekali saja: onboarding yang terbuka lagi (mis. tombol ganda, deep
      // link) tidak boleh menggandakan profil, pengaturan & kantong.
      if (await isSetUp()) throw StateError('Sudah di-setup');
      await _db
          .into(_db.profiles)
          .insert(
            ProfilesCompanion.insert(
              id: _newId(),
              name: userName,
              trialStartedAt: Value(_now()),
            ),
          );
      await _db
          .into(_db.salarySettings)
          .insert(
            SalarySettingsCompanion.insert(
              id: _newId(),
              netSalary: incomeMode == IncomeMode.irregular ? 0 : netSalary,
              payday: payday,
              autoAdd: Value(autoAdd),
              incomeMode: Value(incomeMode),
              frequency: Value(
                incomeMode == IncomeMode.salary
                    ? IncomeFrequency.monthly
                    : frequency,
              ),
              weekday: Value(weekday),
              monthlyEstimate: Value(monthlyEstimate),
              incomeReminder: Value(incomeReminder),
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

  Future<IncomeSchedule?> schedule() async {
    final s = await _salarySettings();
    return s == null ? null : _scheduleOf(s);
  }

  // --------------------------------------------------------------- period

  /// Periode berjalan. Dibuat sekali per siklus (idempoten): aman dipanggil
  /// berkali-kali, juga saat offline. Pemasukan otomatis (gaji/uang jajan)
  /// masuk saat periode dibuat.
  Future<PeriodRow> ensureCurrentPeriod() {
    return _db.transaction(() async {
      final settings = await _salarySettings();
      if (settings == null) throw StateError('Pemasukan belum diatur');
      return _ensurePeriod(settings, _scheduleOf(settings).periodFor(_now()));
    });
  }

  Future<PeriodRow> _ensurePeriod(
    SalarySetting settings,
    PayPeriod period,
  ) async {
    final existing =
        await (_db.select(_db.periods)..where(
              (t) => t.startDate.equals(period.start) & t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (existing != null) return existing;

    final running = settings.incomeMode == IncomeMode.irregular;
    // "Tambah otomatis" mati → periode dibuat dengan pemasukan 0, user mengisi
    // sendiri lewat layar 18 (setPeriodSalary).
    final salary = running || !settings.autoAdd ? 0 : settings.netSalary;
    final periodId = _keyId('period', [period.start.toIso8601String()]);
    await _db
        .into(_db.periods)
        .insert(
          PeriodsCompanion.insert(
            id: periodId,
            startDate: period.start,
            endDate: period.end,
            salary: salary,
            // Penghasilan tidak tetap tidak punya momen "gajian".
            celebrated: Value(running),
          ),
        );
    if (!running) {
      final pockets = await _activePockets();
      final amounts = allocateAll(salary, pockets.map(_ruleOf).toList());
      for (final p in pockets) {
        await _db
            .into(_db.periodAllocations)
            .insert(
              PeriodAllocationsCompanion.insert(
                id: _keyId('alloc', [periodId, p.id]),
                periodId: periodId,
                pocketId: p.id,
                amount: amounts[p.id]!,
              ),
            );
      }
      await _rollover(pockets, period.start, periodId);
    }
    return (_db.select(
      _db.periods,
    )..where((t) => t.id.equals(periodId))).getSingle();
  }

  /// Sisa kantong ber-"pindah ke Dana Darurat" di periode sebelumnya masuk ke
  /// kantong darurat periode baru (layar 22).
  Future<void> _rollover(
    List<PocketRow> pockets,
    DateTime start,
    String periodId,
  ) async {
    final emergency = pockets
        .where((p) => p.type == PocketType.darurat)
        .firstOrNull;
    final sources = pockets.where(
      (p) => p.rolloverToEmergency && p.id != emergency?.id,
    );
    if (emergency == null || sources.isEmpty) return;
    final previous =
        await (_db.select(_db.periods)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.startDate.isSmallerThanValue(start),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.startDate)])
              ..limit(1))
            .getSingleOrNull();
    if (previous == null) return;
    final balances = await _balances(previous.id);
    for (final p in sources) {
      final left = balances[p.id]?.remaining ?? 0;
      if (left <= 0) continue;
      await _db
          .into(_db.transfers)
          .insert(
            TransfersCompanion.insert(
              id: _keyId('rollover', [previous.id, p.id]),
              fromPocketId: p.id,
              toPocketId: emergency.id,
              periodId: previous.id,
              toPeriodId: Value(periodId),
              amount: left,
              occurredAt: start,
            ),
          );
    }
  }

  /// Pemasukan otomatis periode berjalan & pembagiannya (layar 18).
  Future<PaydayInfo> loadPayday() async {
    final period = await ensureCurrentPeriod();
    final settings = (await _salarySettings())!;
    final allocations = await (_db.select(
      _db.periodAllocations,
    )..where((t) => t.periodId.equals(period.id) & t.deletedAt.isNull())).get();
    final refs = await _pocketRefs();
    final pockets = await _activePockets();
    final amountOf = {for (final a in allocations) a.pocketId: a.amount};
    return PaydayInfo(
      periodId: period.id,
      start: dateOnly(period.startDate),
      salary: _baseOf(period),
      celebrated: period.celebrated,
      mode: settings.incomeMode,
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

  /// Isi/ubah pemasukan otomatis satu periode lalu bagi ulang ke kantong.
  /// Saldo awal periode itu (kalau ada) diganti pemasukan ini.
  Future<void> setPeriodSalary(String periodId, int salary) {
    if (salary < 0) throw ArgumentError.value(salary, 'salary');
    return _db.transaction(() async {
      final now = _now();
      await (_db.update(
        _db.periods,
      )..where((t) => t.id.equals(periodId))).write(
        PeriodsCompanion(
          salary: Value(salary),
          opening: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await _reallocate(periodId, salary);
    });
  }

  /// Saldo awal saat baru daftar (layar 42): user jarang pas di hari gajian,
  /// jadi jatah kantong periode berjalan dibagi dari uang aslinya sekarang,
  /// bukan dari gaji. Pemasukan berikutnya dibagi seperti biasa. Penghasilan
  /// tidak tetap: jadi saldo awal berjalan.
  Future<void> setOpeningBalance(int amount) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    return _db.transaction(() async {
      final settings = await _salarySettings();
      if (settings == null) throw StateError('Pemasukan belum diatur');
      final period = await _ensurePeriod(
        settings,
        _scheduleOf(settings).periodFor(_now()),
      );
      await (_db.update(
        _db.periods,
      )..where((t) => t.id.equals(period.id))).write(
        PeriodsCompanion(
          opening: Value(amount),
          // Bukan momen gajian → layar "Gajian masuk!" tidak perlu muncul.
          celebrated: const Value(true),
          updatedAt: Value(_now()),
        ),
      );
      await _reallocate(period.id, amount);
    });
  }

  /// Uang yang dibagi ke kantong di satu periode: saldo awal atau gaji.
  int _baseOf(PeriodRow p) => p.opening ?? p.salary;

  /// Hitung ulang jatah tiap kantong untuk satu periode.
  Future<void> _reallocate(String periodId, int salary) async {
    final now = _now();
    final pockets = await _activePockets();
    final amounts = allocateAll(salary, pockets.map(_ruleOf).toList());
    for (final p in pockets) {
      await _db
          .into(_db.periodAllocations)
          .insert(
            PeriodAllocationsCompanion.insert(
              id: _keyId('alloc', [periodId, p.id]),
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
  }

  // -------------------------------------------------------------- pockets

  /// Pengaturan semua kantong + pemasukan yang dibagi (layar 20).
  Future<PocketSetup> loadPocketSetup() async {
    final period = await ensureCurrentPeriod();
    final settings = (await _salarySettings())!;
    final schedule = _scheduleOf(settings);
    final fromOpening = !schedule.isRunningBalance && period.opening != null;
    return PocketSetup(
      incomeMode: settings.incomeMode,
      base: schedule.isRunningBalance
          ? settings.monthlyEstimate ?? 0
          : fromOpening
          ? period.opening!
          : period.salary > 0
          ? period.salary
          : settings.netSalary,
      perNoun: schedule.perNoun,
      fromOpening: fromOpening,
      pockets: [
        for (final p in await _activePockets())
          PocketConfig(
            id: p.id,
            type: p.type,
            name: p.name,
            iconKey: p.iconKey,
            color: p.color,
            mode: p.mode,
            percent: p.percent,
            nominal: p.nominal,
            rangeMin: p.rangeMin,
            rangeMax: p.rangeMax,
            lowThresholdPercent: p.lowThresholdPercent,
            rolloverToEmergency: p.rolloverToEmergency,
          ),
      ],
    );
  }

  /// Simpan pengaturan & urutan kantong (sesuai urutan [pockets]). Jatah
  /// periode berjalan dihitung ulang; pemasukan yang sudah dibagi tidak diubah.
  /// Kantong yang belum ada di DB ditambahkan. [moves] = kantong yang dihapus
  /// → kantong tujuan: seluruh saldo & riwayatnya pindah ke tujuan (layar 45).
  Future<void> savePockets(
    List<PocketConfig> pockets, {
    Map<String, String> moves = const {},
  }) {
    if (pockets.length < minPockets || pockets.length > maxPockets) {
      throw ArgumentError.value(
        pockets.length,
        'pockets',
        'harus $minPockets-$maxPockets kantong',
      );
    }
    final kept = {for (final p in pockets) p.id};
    for (final MapEntry(key: from, value: to) in moves.entries) {
      if (kept.contains(from) || !kept.contains(to)) {
        throw ArgumentError.value(from, 'moves', 'tujuan tidak valid');
      }
    }
    for (final p in pockets) {
      final name = p.name.trim();
      if (name.isEmpty || name.length > 20) {
        throw ArgumentError.value(p.name, 'name', 'harus 1-20 huruf');
      }
      if (p.percent < 0 || p.percent > 100 || p.nominal < 0) {
        throw ArgumentError.value(p.id, 'jatah', 'di luar batas');
      }
      if (p.rangeMin != null &&
          p.rangeMax != null &&
          p.rangeMin! > p.rangeMax!) {
        throw ArgumentError.value(
          p.rangeMin,
          'rangeMin',
          'lebih dari maksimal',
        );
      }
    }
    return _db.transaction(() async {
      final now = _now();
      final active = {for (final p in await _activePockets()) p.id};
      final orphans = active.difference(kept).difference(moves.keys.toSet());
      if (orphans.isNotEmpty) {
        throw ArgumentError.value(orphans, 'pockets', 'kantong hilang');
      }
      for (final (i, p) in pockets.indexed) {
        final row = PocketsCompanion(
          type: Value(p.type),
          name: Value(p.name.trim()),
          iconKey: Value(p.iconKey),
          color: Value(p.color),
          sortOrder: Value(i),
          mode: Value(p.mode),
          percent: Value(p.percent),
          nominal: Value(p.nominal),
          rangeMin: Value(p.rangeMin),
          rangeMax: Value(p.rangeMax),
          lowThresholdPercent: Value(p.lowThresholdPercent),
          rolloverToEmergency: Value(p.rolloverToEmergency),
          updatedAt: Value(now),
        );
        if (active.contains(p.id)) {
          await (_db.update(
            _db.pockets,
          )..where((t) => t.id.equals(p.id))).write(row);
        } else {
          await _db
              .into(_db.pockets)
              .insert(row.copyWith(id: Value(p.id), createdAt: Value(now)));
        }
      }
      for (final MapEntry(key: from, value: to) in moves.entries) {
        if (active.contains(from)) await _mergePocket(from, to, now);
      }
      final settings = (await _salarySettings())!;
      if (settings.incomeMode != IncomeMode.irregular) {
        final period = await _ensurePeriod(
          settings,
          _scheduleOf(settings).periodFor(now),
        );
        await _reallocate(period.id, _baseOf(period));
      }
    });
  }

  /// Pindahkan seluruh isi kantong [from] ke [to] lalu hapus lunak [from]:
  /// jatah tiap periode, bagian pemasukan, pengeluaran & pindah saldo.
  /// Total uang tidak berubah, riwayatnya tetap ada di kantong tujuan.
  Future<void> _mergePocket(String from, String to, DateTime now) async {
    await (_db.update(_db.expenses)..where((t) => t.pocketId.equals(from)))
        .write(ExpensesCompanion(pocketId: Value(to), updatedAt: Value(now)));

    final periodAllocs = await (_db.select(
      _db.periodAllocations,
    )..where((t) => t.pocketId.equals(from) & t.deletedAt.isNull())).get();
    for (final a in periodAllocs) {
      final target =
          await (_db.select(_db.periodAllocations)..where(
                (t) => t.periodId.equals(a.periodId) & t.pocketId.equals(to),
              ))
              .getSingleOrNull();
      if (target == null) {
        await _db
            .into(_db.periodAllocations)
            .insert(
              PeriodAllocationsCompanion.insert(
                id: _keyId('alloc', [a.periodId, to]),
                periodId: a.periodId,
                pocketId: to,
                amount: a.amount,
              ),
            );
      } else {
        await (_db.update(
          _db.periodAllocations,
        )..where((t) => t.id.equals(target.id))).write(
          PeriodAllocationsCompanion(
            amount: Value(
              (target.deletedAt == null ? target.amount : 0) + a.amount,
            ),
            deletedAt: const Value(null),
            updatedAt: Value(now),
          ),
        );
      }
    }
    await (_db.update(
      _db.periodAllocations,
    )..where((t) => t.pocketId.equals(from))).write(
      PeriodAllocationsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );

    final incomeAllocs = await (_db.select(
      _db.incomeAllocations,
    )..where((t) => t.pocketId.equals(from) & t.deletedAt.isNull())).get();
    for (final a in incomeAllocs) {
      final target =
          await (_db.select(_db.incomeAllocations)..where(
                (t) => t.incomeId.equals(a.incomeId) & t.pocketId.equals(to),
              ))
              .getSingleOrNull();
      if (target == null) {
        await _db
            .into(_db.incomeAllocations)
            .insert(
              IncomeAllocationsCompanion.insert(
                id: _keyId('ialloc', [a.incomeId, to]),
                incomeId: a.incomeId,
                pocketId: to,
                amount: a.amount,
              ),
            );
      } else {
        await (_db.update(
          _db.incomeAllocations,
        )..where((t) => t.id.equals(target.id))).write(
          IncomeAllocationsCompanion(
            amount: Value(
              (target.deletedAt == null ? target.amount : 0) + a.amount,
            ),
            deletedAt: const Value(null),
            updatedAt: Value(now),
          ),
        );
      }
    }
    await (_db.update(
      _db.incomeAllocations,
    )..where((t) => t.pocketId.equals(from))).write(
      IncomeAllocationsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );

    // Pindah saldo antara kedua kantong jadi pindah ke diri sendiri → dibuang.
    await (_db.update(_db.transfers)..where(
          (t) =>
              (t.fromPocketId.equals(from) & t.toPocketId.equals(to)) |
              (t.fromPocketId.equals(to) & t.toPocketId.equals(from)),
        ))
        .write(
          TransfersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
    await (_db.update(
      _db.transfers,
    )..where((t) => t.fromPocketId.equals(from))).write(
      TransfersCompanion(fromPocketId: Value(to), updatedAt: Value(now)),
    );
    await (_db.update(
      _db.transfers,
    )..where((t) => t.toPocketId.equals(from))).write(
      TransfersCompanion(toPocketId: Value(to), updatedAt: Value(now)),
    );

    await (_db.update(_db.pockets)..where((t) => t.id.equals(from))).write(
      PocketsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Sisa saldo & jumlah catatan satu kantong (bottom sheet hapus, layar 45).
  /// Gaji/uang jajan: sisa periode berjalan. Tidak tetap: saldo berjalan.
  Future<({int remaining, int entries})> pocketUsage(String pocketId) async {
    final period = await ensureCurrentPeriod();
    final settings = (await _salarySettings())!;
    final running = _scheduleOf(settings).isRunningBalance;
    final balance = (await _balances(running ? null : period.id))[pocketId];
    final e = _db.expenses;
    final count = e.id.count();
    final row =
        await (_db.selectOnly(e)
              ..addColumns([count])
              ..where(e.pocketId.equals(pocketId) & e.deletedAt.isNull()))
            .getSingle();
    return (remaining: balance?.remaining ?? 0, entries: row.read(count) ?? 0);
  }

  /// Pindahin saldo antar kantong di periode berjalan (layar 25).
  Future<void> transferBalance({
    required String fromPocketId,
    required String toPocketId,
    required int amount,
  }) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    if (fromPocketId == toPocketId) {
      throw ArgumentError.value(toPocketId, 'toPocketId', 'kantong sama');
    }
    return _db.transaction(() async {
      final now = _now();
      final settings = (await _salarySettings())!;
      final running = settings.incomeMode == IncomeMode.irregular;
      final period = await _ensurePeriod(
        settings,
        _scheduleOf(settings).periodFor(now),
      );
      final balances = await _balances(running ? null : period.id);
      final available = balances[fromPocketId]?.remaining ?? 0;
      if (amount > available) {
        throw StateError('Saldo kantong asal cuma $available');
      }
      await _db
          .into(_db.transfers)
          .insert(
            TransfersCompanion.insert(
              id: _newId(),
              fromPocketId: fromPocketId,
              toPocketId: toPocketId,
              periodId: period.id,
              amount: amount,
              occurredAt: now,
            ),
          );
    });
  }

  // --------------------------------------------------------------- income

  /// Tambah pemasukan & langsung bagi ke kantong sesuai aturannya (layar 30).
  Future<String> addIncome({
    required int amount,
    required String title,
    DateTime? occurredAt,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'harus lebih dari 0');
    }
    final when = occurredAt ?? _now();
    return _db.transaction(() async {
      final period = await _periodFor(when);
      final id = _newId();
      await _db
          .into(_db.incomes)
          .insert(
            IncomesCompanion.insert(
              id: id,
              periodId: period.id,
              amount: amount,
              title: title,
              occurredAt: when,
            ),
          );
      final pockets = await _activePockets();
      final parts = splitIncome(amount, pockets.map(_ruleOf).toList());
      for (final p in pockets) {
        await _db
            .into(_db.incomeAllocations)
            .insert(
              IncomeAllocationsCompanion.insert(
                id: _keyId('ialloc', [id, p.id]),
                incomeId: id,
                pocketId: p.id,
                amount: parts[p.id] ?? 0,
              ),
            );
      }
      return id;
    });
  }

  /// Hapus lunak pemasukan beserta pembagiannya.
  Future<void> deleteIncome(String id) {
    return _db.transaction(() async {
      final now = _now();
      await (_db.update(_db.incomes)..where((t) => t.id.equals(id))).write(
        IncomesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (_db.update(
        _db.incomeAllocations,
      )..where((t) => t.incomeId.equals(id))).write(
        IncomeAllocationsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Pemasukan & pembagiannya, `null` jika tidak ada (layar 31).
  /// Ubah pemasukan (nominal, judul, tanggal). Pembagian ke kantong dihitung
  /// ulang dengan aturan kantong sekarang, seperti saat ditambah.
  Future<void> updateIncome(
    String id, {
    required int amount,
    required String title,
    required DateTime occurredAt,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'harus lebih dari 0');
    }
    return _db.transaction(() async {
      final now = _now();
      final period = await _periodFor(occurredAt);
      await (_db.update(_db.incomes)..where((t) => t.id.equals(id))).write(
        IncomesCompanion(
          periodId: Value(period.id),
          amount: Value(amount),
          title: Value(title),
          occurredAt: Value(occurredAt),
          updatedAt: Value(now),
        ),
      );
      // Satu baris per (pemasukan, kantong) → perbarui yang ada; kantong yang
      // sudah dihapus user dibuang dari pembagian.
      final existing = {
        for (final a in await (_db.select(
          _db.incomeAllocations,
        )..where((t) => t.incomeId.equals(id))).get())
          a.pocketId: a,
      };
      final pockets = await _activePockets();
      final parts = splitIncome(amount, pockets.map(_ruleOf).toList());
      final active = {for (final p in pockets) p.id};
      for (final p in pockets) {
        final row = existing[p.id];
        if (row == null) {
          await _db
              .into(_db.incomeAllocations)
              .insert(
                IncomeAllocationsCompanion.insert(
                  id: _keyId('ialloc', [id, p.id]),
                  incomeId: id,
                  pocketId: p.id,
                  amount: parts[p.id] ?? 0,
                ),
              );
        } else {
          await (_db.update(
            _db.incomeAllocations,
          )..where((t) => t.id.equals(row.id))).write(
            IncomeAllocationsCompanion(
              amount: Value(parts[p.id] ?? 0),
              deletedAt: const Value(null),
              updatedAt: Value(now),
            ),
          );
        }
      }
      for (final row in existing.values) {
        if (active.contains(row.pocketId)) continue;
        await (_db.update(
          _db.incomeAllocations,
        )..where((t) => t.id.equals(row.id))).write(
          IncomeAllocationsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Samakan saldo dengan uang asli user (layar Sesuaikan saldo).
  /// Selisih kurang → pengeluaran "Penyesuaian saldo" dari [pocketId];
  /// selisih lebih → pemasukan "Penyesuaian saldo" yang dibagi ke kantong.
  /// Mengembalikan selisihnya (0 = sudah sama, tidak dicatat apa-apa).
  Future<int> adjustBalance({
    required int actual,
    required String pocketId,
  }) async {
    if (actual < 0) throw ArgumentError.value(actual, 'actual');
    final diff = actual - (await loadHome()).remaining;
    if (diff < 0) {
      await addExpense(
        pocketId: pocketId,
        amount: -diff,
        title: adjustmentTitle,
        source: ExpenseSource.adjust,
      );
    } else if (diff > 0) {
      await addIncome(amount: diff, title: adjustmentTitle);
    }
    return diff;
  }

  static const adjustmentTitle = 'Penyesuaian saldo';

  Future<IncomeDetail?> loadIncome(String id) async {
    final row = await (_db.select(
      _db.incomes,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    final allocs = await (_db.select(
      _db.incomeAllocations,
    )..where((t) => t.incomeId.equals(id) & t.deletedAt.isNull())).get();
    final refs = await _pocketRefs();
    final order = {for (final p in await _allPockets()) p.id: p.sortOrder};
    allocs.sort(
      (a, b) => (order[a.pocketId] ?? 0).compareTo(order[b.pocketId] ?? 0),
    );
    final month = DateTime(row.occurredAt.year, row.occurredAt.month);
    return IncomeDetail(
      entry: IncomeEntry(
        id: row.id,
        title: row.title,
        amount: row.amount,
        occurredAt: row.occurredAt,
      ),
      allocations: [
        for (final a in allocs)
          if (refs[a.pocketId] case final ref?) (ref, a.amount),
      ],
      monthTotal: await _incomeTotal(
        month,
        DateTime(month.year, month.month + 1),
      ),
    );
  }

  Stream<IncomeDetail?> watchIncome(String id) => _watch(() => loadIncome(id));

  // -------------------------------------------------------------- expense

  /// Catat pengeluaran. Tanggal harus berada di periode yang sudah tercatat
  /// atau periode berjalan (penghasilan tidak tetap: bulan mana pun).
  Future<String> addExpense({
    required String pocketId,
    required int amount,
    required String title,
    DateTime? occurredAt,
    ExpenseSource source = ExpenseSource.manual,
    String? merchant,
    String? note,
    String? photoPath,
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
              photoPath: Value(photoPath),
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

  /// Catatan yang dibuat user sendiri (manual / scan / pemasukan / gajian
  /// otomatis) bernominal persis sama menjelang [around]. Dipakai catat
  /// otomatis: SMS & email bank bisa telat sampai 48 jam, sementara user
  /// sudah catat duluan (scan memakai jam di struk = jam transaksi).
  /// Catatan dari notifikasi sendiri
  /// tidak dihitung (jajan rutin berharga sama tetap tercatat), dan [exclude]
  /// = catatan yang sudah dipasangkan dengan notifikasi lain.
  /// Mengembalikan id catatannya, atau null.
  Future<String?> findUserEntry({
    required bool income,
    required int amount,
    required DateTime around,
    Set<String> exclude = const {},
    Duration before = const Duration(hours: 48),
    Duration after = const Duration(minutes: 30),
  }) async {
    final from = around.subtract(before);
    final to = around.add(after);
    if (income) {
      final t = _db.incomes;
      final rows =
          await (_db.selectOnly(t)
                ..addColumns([t.id])
                ..where(
                  t.deletedAt.isNull() &
                      t.amount.equals(amount) &
                      t.occurredAt.isBetweenValues(from, to),
                ))
              .get();
      for (final r in rows) {
        final id = r.read(t.id)!;
        if (!exclude.contains(id)) return id;
      }
      // Gajian / uang jajan otomatis (awal periode) = SMS "dana masuk" gaji.
      final p = _db.periods;
      final periods =
          await (_db.selectOnly(p)
                ..addColumns([p.id])
                ..where(
                  p.deletedAt.isNull() &
                      p.salary.equals(amount) &
                      p.startDate.isBetweenValues(dateOnly(from), to),
                ))
              .get();
      for (final r in periods) {
        final id = 'periode:${r.read(p.id)!}';
        if (!exclude.contains(id)) return id;
      }
      return null;
    }
    final t = _db.expenses;
    final rows =
        await (_db.selectOnly(t)
              ..addColumns([t.id])
              ..where(
                t.deletedAt.isNull() &
                    t.source.isNotInValues([
                      ExpenseSource.notif,
                      ExpenseSource.adjust,
                    ]) &
                    t.amount.equals(amount) &
                    t.occurredAt.isBetweenValues(from, to),
              ))
            .get();
    for (final r in rows) {
      final id = r.read(t.id)!;
      if (!exclude.contains(id)) return id;
    }
    return null;
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
    final settings = (await _salarySettings())!;
    final schedule = _scheduleOf(settings);
    final profile =
        await (_db.select(_db.profiles)
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    final today = _now();
    final views = await _pocketViews(
      schedule.isRunningBalance ? null : period.id,
    );
    final remaining = views.fold<int>(0, (s, v) => s + v.balance.remaining);
    final name = profile?.name ?? '';

    if (schedule.isRunningBalance) {
      final month = DateTime(today.year, today.month);
      final last =
          await (_db.select(_db.incomes)
                ..where((t) => t.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
                ..limit(1))
              .getSingleOrNull();
      return HomeSummary(
        userName: name,
        mode: schedule.mode,
        salary: 0,
        pockets: views,
        daysToPayday: 0,
        onTrack: remaining >= 0,
        hint: last == null
            ? 'Belum ada pemasukan, tambah yuk'
            : 'Terakhir masuk ${relativeDay(last.occurredAt, today).toLowerCase()}, +${rupiahShort(last.amount)}',
        monthIncome: await _incomeTotal(
          month,
          DateTime(month.year, month.month + 1),
        ),
      );
    }

    final payPeriod = PayPeriod(
      dateOnly(period.startDate),
      dateOnly(period.endDate),
    );
    final days = payPeriod.daysUntilNextPayday(today);
    final budget = views.fold<int>(0, (s, v) => s + v.balance.available);
    final spent = views.fold<int>(0, (s, v) => s + v.balance.spent);
    final allowance = schedule.mode == IncomeMode.allowance;
    final daily =
        allowance && schedule.effectiveFrequency != IncomeFrequency.daily;
    return HomeSummary(
      userName: name,
      mode: schedule.mode,
      salary: period.salary,
      opening: period.opening,
      pockets: views,
      daysToPayday: days,
      onTrack: isOnTrack(
        spent: spent,
        budget: budget,
        elapsedRatio: payPeriod.elapsedRatio(today),
      ),
      hint: nextIncomeHint(schedule, days, payPeriod.nextPayday),
      periodNoun: schedule.periodNoun,
      perNoun: schedule.perNoun,
      dailySafe: daily
          ? (remaining > 0 ? remaining ~/ (days < 1 ? 1 : days) : 0)
          : null,
      dailySafeUntil: daily
          ? (schedule.effectiveFrequency == IncomeFrequency.weekly
                ? weekdayName(payPeriod.nextPayday.weekday)
                : 'tgl ${payPeriod.nextPayday.day}')
          : null,
    );
  }

  /// Beranda yang otomatis ter-update setiap ada perubahan data.
  Stream<HomeSummary> watchHome() => _watch(loadHome);

  // ------------------------------------------------------------ catatan

  /// Pemasukan & pengeluaran di satu tanggal, urut dari pagi (layar 06/34).
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
    final incomeRows =
        await (_db.select(_db.incomes)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.occurredAt.isBiggerOrEqualValue(start) &
                    t.occurredAt.isSmallerThanValue(end),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
            .get();
    final settings = await _salarySettings();
    final autoTitle = settings?.incomeMode == IncomeMode.allowance
        ? 'Uang jajan masuk'
        : 'Gajian';
    final autoRows =
        await (_db.select(_db.periods)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.startDate.equals(start) &
                  t.salary.isBiggerThanValue(0),
            ))
            .get();
    return DayNotes(
      start,
      await _entries(rows),
      incomes: [
        for (final p in autoRows)
          IncomeEntry(
            id: 'period:${p.id}',
            title: autoTitle,
            amount: p.salary,
            occurredAt: p.startDate,
            auto: true,
          ),
        for (final r in incomeRows)
          IncomeEntry(
            id: r.id,
            title: r.title,
            amount: r.amount,
            occurredAt: r.occurredAt,
          ),
      ],
    );
  }

  Stream<DayNotes> watchDay(DateTime day) => _watch(() => loadDay(day));

  /// Titik warna kantong, tanggal pemasukan & gajian dalam sebulan (layar 06/34).
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

    final incomeDays = <int>{
      for (final r
          in await (_db.select(_db.incomes)..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.occurredAt.isBiggerOrEqualValue(first) &
                    t.occurredAt.isSmallerThanValue(next),
              ))
              .get())
        r.occurredAt.day,
      for (final p
          in await (_db.select(_db.periods)..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.salary.isBiggerThanValue(0) &
                    t.startDate.isBiggerOrEqualValue(first) &
                    t.startDate.isSmallerThanValue(next),
              ))
              .get())
        p.startDate.day,
    };

    final settings = await _salarySettings();
    return CalendarMonth(
      year: year,
      month: month,
      dots: dots,
      incomeDays: incomeDays,
      paydayDay: settings != null && settings.incomeMode == IncomeMode.salary
          ? paydayIn(year, month, settings.payday).day
          : null,
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

  /// Kantong + riwayatnya, terbaru dulu (layar 12). Gaji/uang jajan: periode
  /// berjalan. Penghasilan tidak tetap: saldo berjalan & 100 riwayat terakhir.
  Future<PocketDetail?> loadPocket(String pocketId) async {
    final period = await ensureCurrentPeriod();
    final schedule = _scheduleOf((await _salarySettings())!);
    final running = schedule.isRunningBalance;
    final views = await _pocketViews(running ? null : period.id);
    final view = views.where((v) => v.id == pocketId).firstOrNull;
    if (view == null) return null;
    final pocketRow = await (_db.select(
      _db.pockets,
    )..where((t) => t.id.equals(pocketId))).getSingle();
    final query = _db.select(_db.expenses)
      ..where((t) => t.pocketId.equals(pocketId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    if (running) {
      query.limit(100);
    } else {
      query.where((t) => t.periodId.equals(period.id));
    }
    final payPeriod = PayPeriod(
      dateOnly(period.startDate),
      dateOnly(period.endDate),
    );
    return PocketDetail(
      pocket: view,
      expenses: await _entries(await query.get()),
      daysToPayday: running ? null : payPeriod.daysUntilNextPayday(_now()),
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

  IncomeSchedule _scheduleOf(SalarySetting s) => IncomeSchedule(
    mode: s.incomeMode,
    frequency: s.frequency,
    payday: s.payday,
    weekday: s.weekday,
  );

  Future<List<PocketRow>> _activePockets() =>
      (_db.select(_db.pockets)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  /// Termasuk kantong yang sudah dihapus, agar riwayat lama tetap bernama.
  Future<List<PocketRow>> _allPockets() => (_db.select(
    _db.pockets,
  )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  /// [periodId] null = saldo berjalan (semua waktu).
  Future<List<PocketView>> _pocketViews(String? periodId) async {
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
          mode: p.mode,
          percent: p.percent,
          nominal: p.nominal,
          lowThresholdPercent: p.lowThresholdPercent,
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

  Future<int> _incomeTotal(DateTime from, DateTime to) async {
    final i = _db.incomes;
    final sum = i.amount.sum();
    final row =
        await (_db.selectOnly(i)
              ..addColumns([sum])
              ..where(
                i.deletedAt.isNull() &
                    i.occurredAt.isBiggerOrEqualValue(from) &
                    i.occurredAt.isSmallerThanValue(to),
              ))
            .getSingle();
    return row.read(sum) ?? 0;
  }

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
    final settings = await _salarySettings();
    if (settings == null) throw StateError('Pemasukan belum diatur');
    final schedule = _scheduleOf(settings);
    // Penghasilan tidak tetap: bulan lama boleh dicatat (wadah laporan saja).
    if (schedule.isRunningBalance && !day.isAfter(dateOnly(_now()))) {
      return _ensurePeriod(settings, schedule.periodFor(day));
    }
    final current = await ensureCurrentPeriod();
    final range = PayPeriod(
      dateOnly(current.startDate),
      dateOnly(current.endDate),
    );
    if (range.contains(when)) return current;
    throw StateError('Tanggal $day di luar periode yang tercatat');
  }

  /// Saldo tiap kantong. [periodId] null = saldo berjalan (semua waktu).
  Future<Map<String, PocketBalance>> _balances(String? periodId) async {
    final alloc = <String, int>{};
    void addAlloc(String pocketId, int amount) =>
        alloc[pocketId] = (alloc[pocketId] ?? 0) + amount;

    final periodAllocs = _db.select(_db.periodAllocations)
      ..where((t) => t.deletedAt.isNull());
    if (periodId != null) {
      periodAllocs.where((t) => t.periodId.equals(periodId));
    }
    for (final a in await periodAllocs.get()) {
      addAlloc(a.pocketId, a.amount);
    }

    final incomeQuery = _db.select(_db.incomes)
      ..where((t) => t.deletedAt.isNull());
    if (periodId != null) incomeQuery.where((t) => t.periodId.equals(periodId));
    final incomeIds = [for (final r in await incomeQuery.get()) r.id];
    if (incomeIds.isNotEmpty) {
      final incomeAllocs = await (_db.select(
        _db.incomeAllocations,
      )..where((t) => t.deletedAt.isNull() & t.incomeId.isIn(incomeIds))).get();
      for (final a in incomeAllocs) {
        addAlloc(a.pocketId, a.amount);
      }
    }

    final e = _db.expenses;
    final spentSum = e.amount.sum();
    final spentQuery = _db.selectOnly(e)
      ..addColumns([e.pocketId, spentSum])
      ..where(e.deletedAt.isNull())
      ..groupBy([e.pocketId]);
    if (periodId != null) spentQuery.where(e.periodId.equals(periodId));
    final spent = {
      for (final r in await spentQuery.get())
        r.read(e.pocketId)!: r.read(spentSum) ?? 0,
    };

    final t = _db.transfers;
    final amountSum = t.amount.sum();
    Future<Map<String, int>> transferTotals(
      GeneratedColumn<String> byPocket, {
      required bool incoming,
    }) async {
      final q = _db.selectOnly(t)
        ..addColumns([byPocket, amountSum])
        ..where(t.deletedAt.isNull())
        ..groupBy([byPocket]);
      if (periodId != null) {
        // Masuk dihitung di periode tujuan (sisa yang pindah ke periode baru).
        q.where(
          incoming
              ? t.toPeriodId.equals(periodId) |
                    (t.toPeriodId.isNull() & t.periodId.equals(periodId))
              : t.periodId.equals(periodId),
        );
      }
      return {
        for (final r in await q.get())
          r.read(byPocket)!: r.read(amountSum) ?? 0,
      };
    }

    final incoming = await transferTotals(t.toPocketId, incoming: true);
    final outgoing = await transferTotals(t.fromPocketId, incoming: false);
    final ids = {
      ...alloc.keys,
      ...spent.keys,
      ...incoming.keys,
      ...outgoing.keys,
    };
    return {
      for (final id in ids)
        id: PocketBalance(
          allocation: alloc[id] ?? 0,
          spent: spent[id] ?? 0,
          transferIn: incoming[id] ?? 0,
          transferOut: outgoing[id] ?? 0,
        ),
    };
  }
}
