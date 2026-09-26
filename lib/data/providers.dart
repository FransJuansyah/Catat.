import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/home_summary.dart';
import '../domain/views.dart';
import 'local/database.dart';
import 'repositories/budget_repository.dart';
import 'seed/demo_seed.dart';

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

/// Selesai saat data siap dipakai. Sementara sampai onboarding (F3):
/// isi data contoh jika database masih kosong.
final appReadyProvider = FutureProvider<void>((ref) async {
  await DemoSeed(
    ref.watch(budgetRepositoryProvider),
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
  ).seedIfEmpty();
});

final homeSummaryProvider = StreamProvider<HomeSummary>((ref) async* {
  await ref.watch(appReadyProvider.future);
  yield* ref.watch(budgetRepositoryProvider).watchHome();
});

/// Argumen: tanggal (jam diabaikan).
final dayNotesProvider = StreamProvider.autoDispose.family<DayNotes, DateTime>((
  ref,
  day,
) async* {
  await ref.watch(appReadyProvider.future);
  yield* ref.watch(budgetRepositoryProvider).watchDay(day);
});

/// Argumen: tanggal 1 di bulan yang diminta.
final calendarMonthProvider = StreamProvider.autoDispose
    .family<CalendarMonth, DateTime>((ref, month) async* {
      await ref.watch(appReadyProvider.future);
      yield* ref
          .watch(budgetRepositoryProvider)
          .watchMonth(month.year, month.month);
    });

final expenseDetailProvider = StreamProvider.autoDispose
    .family<ExpenseDetail?, String>((ref, id) async* {
      await ref.watch(appReadyProvider.future);
      yield* ref.watch(budgetRepositoryProvider).watchExpense(id);
    });

final pocketDetailProvider = StreamProvider.autoDispose
    .family<PocketDetail?, String>((ref, id) async* {
      await ref.watch(appReadyProvider.future);
      yield* ref.watch(budgetRepositoryProvider).watchPocket(id);
    });
