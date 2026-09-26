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

/// Pengeluaran di satu tanggal (layar 06 & 26).
class DayNotes {
  const DayNotes(this.day, this.items);

  final DateTime day;
  final List<ExpenseEntry> items;

  int get total => items.fold<int>(0, (s, e) => s + e.amount);
}

/// Penanda kalender satu bulan (layar 06).
class CalendarMonth {
  const CalendarMonth({
    required this.year,
    required this.month,
    required this.dots,
    this.paydayDay,
  });

  final int year;
  final int month;

  /// Tanggal → warna kantong (ARGB) yang punya pengeluaran di hari itu.
  final Map<int, List<int>> dots;

  /// Tanggal gajian di bulan ini, jika gaji sudah diatur.
  final int? paydayDay;
}

/// Detail kantong di periode berjalan (layar 12).
class PocketDetail {
  const PocketDetail({
    required this.pocket,
    required this.expenses,
    required this.daysToPayday,
    required this.lowThresholdPercent,
  });

  final PocketView pocket;
  final List<ExpenseEntry> expenses;
  final int daysToPayday;
  final int lowThresholdPercent;
}
