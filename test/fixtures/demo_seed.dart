import 'package:catat/data/local/database.dart';
import 'package:catat/data/repositories/budget_repository.dart';
import 'package:catat/domain/templates.dart';
import 'package:catat/domain/types.dart';

/// Data contoh sesuai desain Figma (fixture test). Dulu dipakai app sebelum onboarding
/// (F3); kini hanya untuk test. Diisi jika database masih kosong.
class DemoSeed {
  DemoSeed(this._repo, this._db, this._now);

  final BudgetRepository _repo;
  final AppDatabase _db;
  final DateTime Function() _now;

  Future<void> seedIfEmpty() async {
    if (await _repo.isSetUp()) return;

    // Gajian besok → teks "Gajian besok, tahan dulu ya" seperti desain.
    final tomorrow = _now().add(const Duration(days: 1));
    await _repo.setupBudget(
      userName: 'Frans',
      netSalary: 6500000,
      payday: tomorrow.day,
      template: PocketTemplates.klasik,
    );

    final period = await _repo.ensureCurrentPeriod();
    final pockets = await _db.select(_db.pockets).get();
    String pocketOf(PocketType type) =>
        pockets.firstWhere((p) => p.type == type).id;

    // Total: Wajib 2.800.000, Keinginan 1.520.000, Darurat 0 → sisa 2.180.000.
    const expenses = [
      (PocketType.wajib, 'Bayar kos', 1500000, 0, ExpenseSource.manual),
      (PocketType.wajib, 'Pulsa & internet', 200000, 1, ExpenseSource.manual),
      (PocketType.wajib, 'Belanja bulanan', 553000, 3, ExpenseSource.scan),
      (PocketType.wajib, 'Bensin', 300000, 8, ExpenseSource.manual),
      (PocketType.wajib, 'Token listrik', 150000, 20, ExpenseSource.manual),
      (PocketType.keinginan, 'Nongkrong', 500000, 6, ExpenseSource.manual),
      (PocketType.keinginan, 'Skincare', 500000, 12, ExpenseSource.scan),
      (PocketType.keinginan, 'Baju baru', 395000, 16, ExpenseSource.manual),
      (
        PocketType.keinginan,
        'Nonton bioskop',
        100000,
        22,
        ExpenseSource.manual,
      ),
      (PocketType.wajib, 'Belanja Indomaret', 52000, 99, ExpenseSource.scan),
      (PocketType.wajib, 'Makan siang', 45000, 99, ExpenseSource.manual),
      (PocketType.keinginan, 'Kopi susu', 25000, 99, ExpenseSource.scan),
    ];

    final now = _now();
    final start = period.startDate;
    final today = DateTime(now.year, now.month, now.day);
    final maxOffset = today.difference(start).inDays;
    for (final (type, title, amount, offset, source) in expenses) {
      final day = start.add(Duration(days: offset.clamp(0, maxOffset)));
      var at = DateTime(day.year, day.month, day.day, 12);
      if (at.isAfter(now)) at = now;
      await _repo.addExpense(
        pocketId: pocketOf(type),
        amount: amount,
        title: title,
        occurredAt: at,
        source: source,
      );
    }
  }
}
