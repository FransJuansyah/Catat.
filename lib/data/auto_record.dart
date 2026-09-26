import '../domain/bank_notification_parser.dart';
import '../domain/types.dart';
import 'repositories/budget_repository.dart';

/// Hasil catat otomatis (untuk notif "Tercatat …").
class AutoRecord {
  const AutoRecord({
    required this.id,
    required this.income,
    required this.amount,
    required this.title,
    this.pocketName,
  }) : duplicate = false;

  /// Sudah ada catatan user yang sama (manual / scan / gajian) → tidak
  /// dicatat lagi. [id] = catatan yang dipasangkan.
  const AutoRecord.duplicate(this.id)
    : income = false,
      amount = 0,
      title = '',
      pocketName = null,
      duplicate = true;

  final bool duplicate;
  final String id;

  /// true = pemasukan, false = pengeluaran.
  final bool income;
  final int amount;
  final String title;

  /// Kantong pengeluaran (null untuk pemasukan).
  final String? pocketName;

  Map<String, Object?> toMap() => {
    'duplicate': duplicate,
    'id': id,
    'income': income,
    'amount': amount,
    'title': title,
    'pocketName': pocketName,
  };
}

/// Catat transaksi dari notifikasi langsung ke DB, tanpa membuka aplikasi.
/// Pengeluaran masuk ke kantong tebakan (kantong pertama bertipe itu);
/// pemasukan dibagi ke kantong seperti "Tambah pemasukan".
/// [matched] = catatan user yang sudah dipasangkan dengan notifikasi lain
/// (satu catatan manual hanya menyerap satu notifikasi).
/// null = belum di-setup / tidak ada kantong.
Future<AutoRecord?> recordDetected(
  BudgetRepository repo,
  DetectedTransaction t, {
  Set<String> matched = const {},
}) async {
  if (!await repo.isSetUp()) return null;
  final income = t.direction == MoneyDirection.into;
  // User sudah catat manual / scan sebelum notif (bisa telat s.d. 48 jam).
  final existing = await repo.findUserEntry(
    income: income,
    amount: t.amount,
    around: t.occurredAt,
    exclude: matched,
  );
  if (existing != null) return AutoRecord.duplicate(existing);
  if (income) {
    final id = await repo.addIncome(
      amount: t.amount,
      title: t.title,
      occurredAt: t.occurredAt,
    );
    return AutoRecord(id: id, income: true, amount: t.amount, title: t.title);
  }
  final pockets = (await repo.loadHome()).pockets;
  if (pockets.isEmpty) return null;
  final pocket =
      pockets.where((p) => p.type == t.pocketGuess).firstOrNull ??
      pockets.first;
  final id = await repo.addExpense(
    pocketId: pocket.id,
    amount: t.amount,
    title: t.title,
    occurredAt: t.occurredAt,
    merchant: t.counterparty,
    source: ExpenseSource.notif,
  );
  return AutoRecord(
    id: id,
    income: false,
    amount: t.amount,
    title: t.title,
    pocketName: pocket.name,
  );
}

/// Tombol "Batalkan" di notif "Tercatat".
Future<void> undoRecord(
  BudgetRepository repo,
  String id, {
  required bool income,
}) => income ? repo.deleteIncome(id) : repo.deleteExpense(id);
