import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/home_summary.dart';
import '../domain/templates.dart';
import '../domain/views.dart';
import 'local/database.dart';
import 'repositories/budget_repository.dart';

/// Jam sistem. Di-override di test agar tanggal bisa dikontrol.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) =>
      BudgetRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Apakah onboarding (gaji + kantong) sudah selesai. Dipakai Splash.
final isSetUpProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(budgetRepositoryProvider).isSetUp(),
);

final homeSummaryProvider = StreamProvider<HomeSummary>(
  (ref) => ref.watch(budgetRepositoryProvider).watchHome(),
);

final paydayProvider = StreamProvider<PaydayInfo>(
  (ref) => ref.watch(budgetRepositoryProvider).watchPayday(),
);

/// Argumen: tanggal (jam diabaikan).
final dayNotesProvider = StreamProvider.autoDispose.family<DayNotes, DateTime>(
  (ref, day) => ref.watch(budgetRepositoryProvider).watchDay(day),
);

/// Argumen: tanggal 1 di bulan yang diminta.
final calendarMonthProvider = StreamProvider.autoDispose
    .family<CalendarMonth, DateTime>(
      (ref, month) => ref
          .watch(budgetRepositoryProvider)
          .watchMonth(month.year, month.month),
    );

final expenseDetailProvider = StreamProvider.autoDispose
    .family<ExpenseDetail?, String>(
      (ref, id) => ref.watch(budgetRepositoryProvider).watchExpense(id),
    );

final pocketDetailProvider = StreamProvider.autoDispose
    .family<PocketDetail?, String>(
      (ref, id) => ref.watch(budgetRepositoryProvider).watchPocket(id),
    );

// ------------------------------------------------------------- onboarding

/// Isian onboarding (layar 02 & 19) sebelum disimpan.
class OnboardingDraft {
  const OnboardingDraft({
    this.salary = 0,
    this.payday = 25,
    this.autoAdd = true,
    this.template = PocketTemplates.klasik,
  });

  final int salary;
  final int payday;
  final bool autoAdd;
  final PocketTemplate template;

  OnboardingDraft copyWith({
    int? salary,
    int? payday,
    bool? autoAdd,
    PocketTemplate? template,
  }) => OnboardingDraft(
    salary: salary ?? this.salary,
    payday: payday ?? this.payday,
    autoAdd: autoAdd ?? this.autoAdd,
    template: template ?? this.template,
  );
}

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void setSalary(int v) => state = state.copyWith(salary: v);
  void setPayday(int v) => state = state.copyWith(payday: v);
  void setAutoAdd(bool v) => state = state.copyWith(autoAdd: v);
  void setTemplate(PocketTemplate t) => state = state.copyWith(template: t);

  /// Simpan semuanya & buat periode pertama.
  Future<void> finish() async {
    final repo = ref.read(budgetRepositoryProvider);
    await repo.setupBudget(
      netSalary: state.salary,
      payday: state.payday,
      autoAdd: state.autoAdd,
      template: state.template,
    );
    final period = await repo.ensureCurrentPeriod();
    // Gaji bulan pertama baru saja diisi user, jadi langsung dipakai walau
    // "Tambah otomatis" mati (bulan-bulan berikutnya diisi manual).
    if (!state.autoAdd) await repo.setPeriodSalary(period.id, state.salary);
    ref.invalidate(isSetUpProvider);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
      OnboardingController.new,
    );
