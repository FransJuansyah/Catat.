import 'home_summary.dart';
import 'types.dart';

/// Identitas kantong untuk ditampilkan di baris pengeluaran.
class PocketRef {
  const PocketRef({
    required this.id,
    required this.type,
    required this.name,
    required this.iconKey,
    required this.color,
  });

  final String id;
  final PocketType type;
  final String name;
  final String iconKey;
  final int color;
}

/// Satu pengeluaran di daftar (layar 06, 12).
class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.occurredAt,
    required this.source,
    required this.pocket,
    required this.iconKey,
  });

  final String id;
  final String title;
  final int amount;
  final DateTime occurredAt;
  final ExpenseSource source;
  final PocketRef pocket;

  /// Ikon kategori, ditebak dari judul (lihat expense_icon.dart).
  final String iconKey;
}

class ExpenseLine {
  const ExpenseLine(this.name, this.qty, this.price);
  final String name;
  final int qty;
  final int price;
}

/// Detail satu pengeluaran (layar 13).
class ExpenseDetail {
  const ExpenseDetail({
    required this.entry,
    required this.items,
    this.merchant,
    this.photoPath,
    this.note,
  });

  final ExpenseEntry entry;
  final List<ExpenseLine> items;
  final String? merchant;
  final String? photoPath;
  final String? note;
}

/// Satu pemasukan di daftar (layar 34). `auto` = gaji/uang jajan otomatis
/// awal periode (tidak bisa dihapus dari catatan).
class IncomeEntry {
  const IncomeEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.occurredAt,
    this.auto = false,
  });

  final String id;
  final String title;
  final int amount;
  final DateTime occurredAt;
  final bool auto;
}

/// Pemasukan beserta pembagiannya ke kantong (layar 31).
class IncomeDetail {
  const IncomeDetail({
    required this.entry,
    required this.allocations,
    required this.monthTotal,
  });

  final IncomeEntry entry;
  final List<(PocketRef, int)> allocations;

  /// Total pemasukan di bulan kalender yang sama.
  final int monthTotal;
}

/// Pemasukan & pengeluaran di satu tanggal (layar 06, 26, 34).
class DayNotes {
  const DayNotes(this.day, this.items, {this.incomes = const []});

  final DateTime day;
  final List<ExpenseEntry> items;
  final List<IncomeEntry> incomes;

  int get total => items.fold<int>(0, (s, e) => s + e.amount);
  int get incomeTotal => incomes.fold<int>(0, (s, e) => s + e.amount);
  bool get isEmpty => items.isEmpty && incomes.isEmpty;
}

/// Penanda kalender satu bulan (layar 06, 34).
class CalendarMonth {
  const CalendarMonth({
    required this.year,
    required this.month,
    required this.dots,
    this.paydayDay,
    this.incomeDays = const {},
  });

  final int year;
  final int month;

  /// Tanggal → warna kantong (ARGB) yang punya pengeluaran di hari itu.
  final Map<int, List<int>> dots;

  /// Tanggal gajian di bulan ini (hanya gaji bulanan).
  final int? paydayDay;

  /// Tanggal yang ada pemasukannya (ditandai hijau).
  final Set<int> incomeDays;
}

/// Pemasukan otomatis periode berjalan & pembagiannya (layar 18).
class PaydayInfo {
  const PaydayInfo({
    required this.periodId,
    required this.start,
    required this.salary,
    required this.celebrated,
    required this.allocations,
    this.mode = IncomeMode.salary,
  });

  final String periodId;

  /// Hari pemasukan (awal periode).
  final DateTime start;
  final int salary;
  final bool celebrated;
  final List<(PocketRef, int)> allocations;
  final IncomeMode mode;

  /// Pemasukan periode ini belum diisi (opsi "Tambah otomatis" mati).
  bool get needsSalary => salary == 0;
}

/// Detail kantong (layar 12). Untuk penghasilan tidak tetap berisi saldo
/// berjalan & [daysToPayday] = null.
class PocketDetail {
  const PocketDetail({
    required this.pocket,
    required this.expenses,
    required this.daysToPayday,
    required this.lowThresholdPercent,
  });

  final PocketView pocket;
  final List<ExpenseEntry> expenses;
  final int? daysToPayday;
  final int lowThresholdPercent;
}
