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

class SalarySettings extends Table with SyncedRow {
  IntColumn get netSalary =>
      integer().check(netSalary.isBiggerOrEqualValue(0))();
  IntColumn get payday => integer().check(payday.isBetweenValues(1, 31))();
  BoolColumn get autoAdd => boolean().withDefault(const Constant(true))();
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
  TextColumn get periodId => text().references(Periods, #id)();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  DateTimeColumn get occurredAt => dateTime()();
}

@DriftDatabase(
  tables: [
    Profiles,
    SalarySettings,
    Pockets,
    Periods,
    PeriodAllocations,
    Expenses,
    ExpenseItems,
    Transfers,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Tanpa argumen = file SQLite di HP. Test memakai `NativeDatabase.memory()`.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'catat'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(periods, periods.celebrated);
        // Periode lama dianggap sudah dirayakan supaya tidak muncul ulang.
        await customStatement('UPDATE periods SET celebrated = 1');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
