import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bug nyata di HP: onboarding terbuka lagi di HP yang sudah terdaftar →
/// profil, pengaturan gaji & kantong jadi dobel (9 kantong).
void main() {
  late AppDatabase db;
  late BudgetRepository repo;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = BudgetRepository(db, () => DateTime(2026, 9, 26));
  });
  tearDown(() => db.close());

  test('setup kedua ditolak, data pertama utuh', () async {
    await repo.setupBudget(
      incomeMode: IncomeMode.irregular,
      netSalary: 0,
      template: PocketTemplates.freelancer,
    );
    await expectLater(
      repo.setupBudget(
        netSalary: 5800000,
        payday: 28,
        template: PocketTemplates.forMode(IncomeMode.salary).first,
      ),
      throwsStateError,
    );

    expect(await db.select(db.profiles).get(), hasLength(1));
    final settings = await db.select(db.salarySettings).get();
    expect(settings, hasLength(1));
    expect(settings.single.incomeMode, IncomeMode.irregular);
    expect(
      await db.select(db.pockets).get(),
      hasLength(PocketTemplates.freelancer.pockets.length),
    );
  });
}
