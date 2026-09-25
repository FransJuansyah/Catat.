import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/home_summary.dart';
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

final homeSummaryProvider = StreamProvider<HomeSummary>((ref) async* {
  final repo = ref.watch(budgetRepositoryProvider);
  // Sementara sampai onboarding (F3): isi data contoh jika kosong.
  await DemoSeed(
    repo,
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
  ).seedIfEmpty();
  yield* repo.watchHome();
});
