// Drift memakai getter yang merujuk dirinya sendiri untuk CHECK constraint.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/types.dart';

part 'database.g.dart';

/// Kolom wajib semua tabel (id uuid + jejak waktu untuk sinkronisasi & soft delete).
mixin SyncedRow on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Profiles extends Table with SyncedRow {
  TextColumn get name => text()();
}

/// Pengaturan pemasukan user (nama tabel historis: dulu hanya gaji).
class SalarySettings extends Table with SyncedRow {
  /// Nominal pemasukan otomatis per siklus (gaji / uang jajan). 0 untuk
  /// penghasilan tidak tetap.
  IntColumn get netSalary =>
      integer().check(netSalary.isBiggerOrEqualValue(0))();

  /// Tanggal (1–31) untuk siklus bulanan.
  IntColumn get payday => integer().check(payday.isBetweenValues(1, 31))();
  BoolColumn get autoAdd => boolean().withDefault(const Constant(true))();
  TextColumn get incomeMode =>
      textEnum<IncomeMode>().withDefault(Constant(IncomeMode.salary.name))();
  TextColumn get frequency => textEnum<IncomeFrequency>().withDefault(
    Constant(IncomeFrequency.monthly.name),
  )();

  /// Hari (1 = Senin … 7 = Minggu) untuk siklus mingguan.
  IntColumn get weekday => integer().withDefault(const Constant(1))();

  /// Perkiraan pemasukan sebulan (opsional, penghasilan tidak tetap).
  IntColumn get monthlyEstimate => integer().nullable()();
  BoolColumn get incomeReminder =>
      boolean().withDefault(const Constant(false))();
}

@DataClassName('PocketRow')
class Pockets extends Table with SyncedRow {
  TextColumn get type => textEnum<PocketType>()();
  TextColumn get name => text().withLength(min: 1, max: 20)();
  TextColumn get iconKey => text()();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get mode => textEnum<AllocationMode>().withDefault(
    Constant(AllocationMode.percent.name),
  )();
  IntColumn get percent => integer().withDefault(const Constant(0))();
  IntColumn get nominal => integer().withDefault(const Constant(0))();
  IntColumn get rangeMin => integer().nullable()();
  IntColumn get rangeMax => integer().nullable()();
  IntColumn get lowThresholdPercent =>
      integer().withDefault(const Constant(20))();
  BoolColumn get rolloverToEmergency =>
      boolean().withDefault(const Constant(false))();
}

@DataClassName('PeriodRow')
class Periods extends Table with SyncedRow {
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  IntColumn get salary => integer()();
  BoolColumn get autoCreated => boolean().withDefault(const Constant(true))();

  /// Layar "Gajian masuk!" (18) sudah ditampilkan untuk periode ini.
  BoolColumn get celebrated => boolean().withDefault(const Constant(false))();

  /// Saldo awal user saat baru daftar (layar 42). Diisi → jatah kantong
  /// periode ini dibagi dari angka ini, bukan dari [salary].
  IntColumn get opening => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {startDate},
  ];
}

class PeriodAllocations extends Table with SyncedRow {
  TextColumn get periodId => text().references(Periods, #id)();
  TextColumn get pocketId => text().references(Pockets, #id)();
  IntColumn get amount => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {periodId, pocketId},
  ];
}

@DataClassName('ExpenseRow')
class Expenses extends Table with SyncedRow {
  TextColumn get pocketId => text().references(Pockets, #id)();
  TextColumn get periodId => text().references(Periods, #id)();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  TextColumn get title => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get source => textEnum<ExpenseSource>()();
  TextColumn get merchant => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get note => text().nullable()();
}

class ExpenseItems extends Table with SyncedRow {
  TextColumn get expenseId => text().references(Expenses, #id)();
  TextColumn get name => text()();
  IntColumn get qty => integer().withDefault(const Constant(1))();
  IntColumn get price => integer()();
}

@DataClassName('TransferRow')
class Transfers extends Table with SyncedRow {
  @ReferenceName('outgoingTransfers')
  TextColumn get fromPocketId => text().references(Pockets, #id)();
  @ReferenceName('incomingTransfers')
  TextColumn get toPocketId => text().references(Pockets, #id)();

  /// Periode asal (saldo keluar dihitung di sini).
  TextColumn get periodId => text().references(Periods, #id)();

  /// Periode tujuan bila beda dengan asal: sisa akhir periode yang pindah ke
  /// Dana Darurat periode berikutnya. null = periode yang sama.
  @ReferenceName('incomingPeriodTransfers')
  TextColumn get toPeriodId => text().nullable().references(Periods, #id)();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  DateTimeColumn get occurredAt => dateTime()();
}

/// Pemasukan yang ditambah user (penghasilan tidak tetap, bonus, dll.).
@DataClassName('IncomeRow')
class Incomes extends Table with SyncedRow {
  TextColumn get periodId => text().references(Periods, #id)();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  TextColumn get title => text()();
  DateTimeColumn get occurredAt => dateTime()();
}

/// Bagian satu pemasukan untuk tiap kantong.
class IncomeAllocations extends Table with SyncedRow {
  TextColumn get incomeId => text().references(Incomes, #id)();
  TextColumn get pocketId => text().references(Pockets, #id)();
  IntColumn get amount => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {incomeId, pocketId},
  ];
}

/// Antrian perubahan lokal yang belum dikirim ke akun (F8). Diisi otomatis
/// oleh trigger SQLite di tiap tabel data, jadi tidak ada perubahan yang lolos.
class SyncOutbox extends Table {
  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get rowId => text()();

  /// Urutan perubahan; baris yang berubah lagi saat dikirim tidak ikut dihapus.
  IntColumn get seq => integer()();

  /// Waktu perubahan (detik unix): penentu "yang terakhir menang" di akun.
  IntColumn get changedAt => integer()();

  @override
  Set<Column> get primaryKey => {tableName_, rowId};
}

/// Status sinkron (kunci-nilai): waktu tarik terakhir, penanda sedang
/// menerapkan data dari akun (trigger outbox dimatikan), dll.
class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Tabel data yang ikut sinkron, urut induk → anak.
const syncedTables = [
  'profiles',
  'salary_settings',
  'pockets',
  'periods',
  'period_allocations',
  'incomes',
  'income_allocations',
  'expenses',
  'expense_items',
  'transfers',
];

@DriftDatabase(
  tables: [
    SyncOutbox,
    SyncMeta,
    Profiles,
    SalarySettings,
    Pockets,
    Periods,
    PeriodAllocations,
    Expenses,
    ExpenseItems,
    Transfers,
    Incomes,
    IncomeAllocations,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Tanpa argumen = file SQLite di HP. Test memakai `NativeDatabase.memory()`.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'catat'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSyncTriggers();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(periods, periods.celebrated);
        // Periode lama dianggap sudah dirayakan supaya tidak muncul ulang.
        await customStatement('UPDATE periods SET celebrated = 1');
      }
      if (from < 3) {
        // Multi pemasukan: user lama otomatis bertipe gaji bulanan (default).
        await m.addColumn(salarySettings, salarySettings.incomeMode);
        await m.addColumn(salarySettings, salarySettings.frequency);
        await m.addColumn(salarySettings, salarySettings.weekday);
        await m.addColumn(salarySettings, salarySettings.monthlyEstimate);
        await m.addColumn(salarySettings, salarySettings.incomeReminder);
        await m.createTable(incomes);
        await m.createTable(incomeAllocations);
      }
      if (from < 4) {
        await m.addColumn(transfers, transfers.toPeriodId);
      }
      if (from < 5) {
        await m.addColumn(periods, periods.opening);
      }
      if (from < 6) {
        await m.createTable(syncOutbox);
        await m.createTable(syncMeta);
        await _createSyncTriggers();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Tiap insert/update/delete di tabel data → masuk [SyncOutbox], kecuali
  /// saat menerapkan data dari akun (sync_meta.applying = 1).
  Future<void> _createSyncTriggers() async {
    for (final t in syncedTables) {
      for (final (op, row) in [
        ('INSERT', 'NEW'),
        ('UPDATE', 'NEW'),
        ('DELETE', 'OLD'),
      ]) {
        await customStatement('''
CREATE TRIGGER IF NOT EXISTS sync_${t}_${op.toLowerCase()} AFTER $op ON $t
WHEN NOT EXISTS (SELECT 1 FROM sync_meta WHERE key = 'applying' AND value = '1')
BEGIN
  INSERT INTO sync_outbox (table_name, row_id, seq, changed_at)
  VALUES ('$t', $row.id, (SELECT COALESCE(MAX(seq), 0) + 1 FROM sync_outbox),
    CAST(strftime('%s', 'now') AS INTEGER))
  ON CONFLICT (table_name, row_id)
  DO UPDATE SET seq = excluded.seq, changed_at = excluded.changed_at;
END''');
      }
    }
  }
}
