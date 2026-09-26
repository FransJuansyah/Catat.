import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/home_summary.dart';
import '../domain/pocket_config.dart';
import '../domain/templates.dart';
import '../domain/types.dart';
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
final incomeDetailProvider = StreamProvider.autoDispose
    .family<IncomeDetail?, String>(
      (ref, id) => ref.watch(budgetRepositoryProvider).watchIncome(id),
    );

// ------------------------------------------------------------- onboarding

/// Isian onboarding (layar 27, 02/28/29, 19) sebelum disimpan.
class OnboardingDraft {
  const OnboardingDraft({
    this.mode = IncomeMode.salary,
    this.amount = 0,
    this.frequency = IncomeFrequency.monthly,
    this.payday = 25,
    this.weekday = 1,
    this.autoAdd = true,
    this.monthlyEstimate = 0,
    this.reminder = true,
    this.template = PocketTemplates.klasik,
  });

  final IncomeMode mode;

  /// Gaji per bulan / uang jajan per siklus. Tidak dipakai untuk tidak tetap.
  final int amount;
  final IncomeFrequency frequency;
  final int payday;
  final int weekday;
  final bool autoAdd;

  /// Perkiraan sebulan (opsional, tidak tetap). 0 = tidak diisi.
  final int monthlyEstimate;
  final bool reminder;
  final PocketTemplate template;

  /// Tombol "Lanjut" di langkah 3 boleh ditekan.
  bool get amountReady => mode == IncomeMode.irregular || amount > 0;

  OnboardingDraft copyWith({
    IncomeMode? mode,
    int? amount,
    IncomeFrequency? frequency,
    int? payday,
    int? weekday,
    bool? autoAdd,
    int? monthlyEstimate,
    bool? reminder,
    PocketTemplate? template,
  }) => OnboardingDraft(
    mode: mode ?? this.mode,
    amount: amount ?? this.amount,
    frequency: frequency ?? this.frequency,
    payday: payday ?? this.payday,
    weekday: weekday ?? this.weekday,
    autoAdd: autoAdd ?? this.autoAdd,
    monthlyEstimate: monthlyEstimate ?? this.monthlyEstimate,
    reminder: reminder ?? this.reminder,
    template: template ?? this.template,
  );
}

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  /// Ganti tipe pemasukan → template & frekuensi default ikut menyesuaikan.
  void setMode(IncomeMode m) => state = state.copyWith(
    mode: m,
    template: PocketTemplates.forMode(m).first,
    frequency: m == IncomeMode.allowance
        ? IncomeFrequency.weekly
        : IncomeFrequency.monthly,
  );
  void setAmount(int v) => state = state.copyWith(amount: v);
  void setFrequency(IncomeFrequency v) => state = state.copyWith(frequency: v);
  void setPayday(int v) => state = state.copyWith(payday: v);
  void setWeekday(int v) => state = state.copyWith(weekday: v);
  void setAutoAdd(bool v) => state = state.copyWith(autoAdd: v);
  void setMonthlyEstimate(int v) => state = state.copyWith(monthlyEstimate: v);
  void setReminder(bool v) => state = state.copyWith(reminder: v);
  void setTemplate(PocketTemplate t) => state = state.copyWith(template: t);

  /// Simpan semuanya & buat periode pertama.
  Future<void> finish() async {
    final repo = ref.read(budgetRepositoryProvider);
    final d = state;
    await repo.setupBudget(
      incomeMode: d.mode,
      netSalary: d.mode == IncomeMode.irregular ? 0 : d.amount,
      frequency: d.frequency,
      payday: d.payday,
      weekday: d.weekday,
      autoAdd: d.autoAdd,
      monthlyEstimate: d.monthlyEstimate > 0 ? d.monthlyEstimate : null,
      incomeReminder: d.mode == IncomeMode.irregular && d.reminder,
      template: d.template,
    );
    final period = await repo.ensureCurrentPeriod();
    // Pemasukan pertama baru saja diisi user, jadi langsung dipakai walau
    // "Tambah otomatis" mati (periode berikutnya diisi manual).
    if (d.mode != IncomeMode.irregular && !d.autoAdd) {
      await repo.setPeriodSalary(period.id, d.amount);
    }
    ref.invalidate(isSetUpProvider);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
      OnboardingController.new,
    );

// ---------------------------------------------------------- atur kantong

/// Isian layar Atur Kantong (20–22) sebelum disimpan.
class PocketDraft {
  const PocketDraft({
    required this.original,
    required this.current,
    this.lastEditedId,
  });

  final PocketSetup original;
  final PocketSetup current;

  /// Kantong terakhir diubah → disorot kalau alokasi belum pas (layar 23).
  final String? lastEditedId;

  bool get dirty => !listEquals(original.pockets, current.pockets);

  PocketConfig pocket(String id) =>
      current.pockets.firstWhere((p) => p.id == id);

  PocketDraft copyWith({PocketSetup? current, String? lastEditedId}) =>
      PocketDraft(
        original: original,
        current: current ?? this.current,
        lastEditedId: lastEditedId ?? this.lastEditedId,
      );
}

class PocketDraftController extends AsyncNotifier<PocketDraft> {
  @override
  Future<PocketDraft> build() async {
    final setup = await ref.read(budgetRepositoryProvider).loadPocketSetup();
    return PocketDraft(original: setup, current: setup);
  }

  void _setPockets(List<PocketConfig> pockets, {String? edited}) {
    final d = state.value;
    if (d == null) return;
    state = AsyncData(
      d.copyWith(
        current: d.current.copyWith(pockets: pockets),
        lastEditedId: edited,
      ),
    );
  }

  /// Ubah satu kantong (layar 21 & 22).
  void updatePocket(PocketConfig pocket) {
    final d = state.value;
    if (d == null) return;
    _setPockets([
      for (final p in d.current.pockets) p.id == pocket.id ? pocket : p,
    ], edited: pocket.id);
  }

  /// Tab Persen / Nominal di layar 20: semua kantong pindah satuan.
  void setAllMode(AllocationMode mode) {
    final d = state.value;
    if (d == null) return;
    _setPockets([
      for (final p in d.current.pockets) p.withMode(mode, d.current.base),
    ]);
  }

  /// [newIndex] = posisi akhir setelah item dipindah.
  void reorder(int oldIndex, int newIndex) {
    final d = state.value;
    if (d == null) return;
    final list = [...d.current.pockets];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    _setPockets(list);
  }

  /// "Rapiin otomatis" (layar 23).
  void autoBalance() {
    final d = state.value;
    if (d == null) return;
    _setPockets(balancePockets(d.current.pockets, d.current.base));
  }

  Future<void> save() async {
    final d = state.value;
    if (d == null) return;
    await ref.read(budgetRepositoryProvider).savePockets(d.current.pockets);
    state = AsyncData(PocketDraft(original: d.current, current: d.current));
  }
}

final pocketDraftProvider =
    AsyncNotifierProvider.autoDispose<PocketDraftController, PocketDraft>(
      PocketDraftController.new,
    );
