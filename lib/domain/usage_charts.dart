import 'expense_icon.dart';
import 'report.dart';
import 'types.dart';
import 'views.dart';

/// Bahan grafik ala pemakaian baterai & data (layar 59, 64).

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Penyesuaian saldo bukan jajan → tidak ikut grafik pemakaian.
Iterable<ReportExpense> _spending(Iterable<ReportExpense> expenses) =>
    expenses.where((e) => e.source != ExpenseSource.adjust);

/// Total pengeluaran per hari, mulai [start] selama [days] hari.
List<int> dailyTotals(
  Iterable<ReportExpense> expenses,
  DateTime start,
  int days,
) {
  final first = _day(start);
  final totals = List<int>.filled(days, 0);
  for (final e in _spending(expenses)) {
    final i = _day(e.occurredAt).difference(first).inDays;
    if (i >= 0 && i < days) totals[i] += e.amount;
  }
  return totals;
}

/// Pemakaian 7 hari terakhir (kartu di Beranda, layar 59).
class WeekUsage {
  const WeekUsage({required this.days, required this.totals});

  /// 7 tanggal, terlama dulu; terakhir = hari ini.
  final List<DateTime> days;
  final List<int> totals;

  int get peakIndex {
    var best = days.length - 1;
    for (var i = 0; i < totals.length; i++) {
      if (totals[i] > totals[best]) best = i;
    }
    return best;
  }

  int get total => totals.fold(0, (s, v) => s + v);

  /// Rata-rata per hari dari hari-hari yang ada pengeluarannya.
  int get average {
    final used = totals.where((v) => v > 0);
    return used.isEmpty
        ? 0
        : (used.fold(0, (s, v) => s + v) / used.length).round();
  }

  /// Satu kalimat di atas grafik, mis. "Sabtu kamu keluar 3x lipat dari biasanya."
  String insight(String Function(DateTime) dayName) {
    if (total == 0) return 'Belum ada pengeluaran 7 hari ini. Hemat parah!';
    final peak = peakIndex;
    final others = [
      for (var i = 0; i < totals.length; i++)
        if (i != peak && totals[i] > 0) totals[i],
    ];
    final label = peak == days.length - 1
        ? 'Hari ini'
        : peak == days.length - 2
        ? 'Kemarin'
        : dayName(days[peak]);
    if (others.isNotEmpty) {
      final usual = others.fold(0, (s, v) => s + v) / others.length;
      final ratio = totals[peak] / usual;
      if (ratio >= 2) {
        return '$label kamu keluar ${ratio.round()}x lipat dari biasanya.';
      }
      return 'Pengeluaranmu stabil minggu ini. Pertahankan!';
    }
    return '$label paling banyak keluar minggu ini.';
  }
}

WeekUsage weekUsage(Iterable<ReportExpense> expenses, DateTime today) {
  final start = _day(today).subtract(const Duration(days: 6));
  return WeekUsage(
    days: [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ],
    totals: dailyTotals(expenses, start, 7),
  );
}

/// Level saldo per hari satu bulan (ala grafik level baterai, layar 64).
class BalanceLevels {
  const BalanceLevels({required this.levels, required this.incomeDays});

  /// Indeks = tanggal - 1. 0..1, `null` = hari yang belum lewat.
  final List<double?> levels;

  /// Tanggal (1..31) yang ada uang masuknya ("ngecas").
  final Set<int> incomeDays;
}

/// Saldo akhir tiap hari = saldo awal + uang masuk − keluar sampai hari itu.
/// [endBalance] = saldo sekarang (bulan berjalan) supaya saldo awal tepat;
/// bulan lalu tanpa saldo akhir → titik terendah dianggap 0.
BalanceLevels balanceLevels({
  required DateTime month,
  required Iterable<ReportExpense> expenses,
  required Iterable<IncomeEntry> incomes,
  required DateTime today,
  int? endBalance,
}) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  final isCurrent = month.year == today.year && month.month == today.month;
  final lastDay = isCurrent ? today.day : days;
  final net = List<int>.filled(days, 0);
  final incomeDays = <int>{};
  for (final i in incomes) {
    if (i.occurredAt.year != month.year || i.occurredAt.month != month.month) {
      continue;
    }
    net[i.occurredAt.day - 1] += i.amount;
    if (i.amount > 0) incomeDays.add(i.occurredAt.day);
  }
  for (final e in expenses) {
    if (e.occurredAt.year != month.year || e.occurredAt.month != month.month) {
      continue;
    }
    net[e.occurredAt.day - 1] -= e.amount;
  }
  final running = <int>[];
  var sum = 0;
  for (var d = 0; d < lastDay; d++) {
    sum += net[d];
    running.add(sum);
  }
  if (running.isEmpty) {
    return BalanceLevels(
      levels: List.filled(days, null),
      incomeDays: incomeDays,
    );
  }
  final lowest = running.reduce((a, b) => a < b ? a : b);
  final start = endBalance != null && isCurrent
      ? endBalance - running.last
      : (lowest < 0 ? -lowest : 0);
  final balances = [for (final r in running) start + r];
  final highest = balances.reduce((a, b) => a > b ? a : b);
  return BalanceLevels(
    levels: [
      for (var d = 0; d < days; d++)
        d < lastDay
            ? (highest <= 0 ? 0.0 : (balances[d] / highest).clamp(0.0, 1.0))
            : null,
    ],
    incomeDays: incomeDays,
  );
}

/// Satu baris "Paling banyak makan duit" (ala daftar aplikasi boros kuota).
class SpendGroup {
  const SpendGroup({
    required this.label,
    required this.iconKey,
    required this.pocket,
    required this.count,
    required this.total,
  });

  final String label;
  final String iconKey;

  /// Kantong yang paling banyak dipakai grup ini (warna baris).
  final PocketRef pocket;
  final int count;
  final int total;
}

const _categoryLabels = {
  'coffee': 'Kopi & jajan',
  'food': 'Makan',
  'fuel': 'Bensin',
  'car': 'Transport',
  'house': 'Kos & rumah',
  'phone': 'Pulsa & internet',
  'bag': 'Belanja',
  'bolt': 'Listrik & air',
  'film': 'Hiburan',
  'shirt': 'Baju',
  'heart': 'Kesehatan',
  'gift': 'Hadiah & traktir',
};

/// Kelompokkan pengeluaran per kategori (ditebak dari judul) atau per judul
/// kalau kategorinya tidak ketemu. Terbesar dulu.
List<SpendGroup> topSpending(
  Iterable<ReportExpense> expenses, {
  int limit = 4,
}) {
  final groups = <String, List<ReportExpense>>{};
  for (final e in _spending(expenses)) {
    final cat = guessExpenseIcon(e.title, fallback: '');
    final key = cat.isNotEmpty
        ? 'cat:$cat'
        : 'title:${e.title.trim().toLowerCase()}';
    (groups[key] ??= []).add(e);
  }
  final result = [
    for (final MapEntry(:key, value: list) in groups.entries)
      () {
        final byPocket = <String, int>{};
        for (final e in list) {
          byPocket[e.pocket.id] = (byPocket[e.pocket.id] ?? 0) + e.amount;
        }
        final topPocketId = byPocket.entries
            .reduce((a, b) => b.value > a.value ? b : a)
            .key;
        final pocket = list
            .firstWhere((e) => e.pocket.id == topPocketId)
            .pocket;
        final cat = key.startsWith('cat:') ? key.substring(4) : null;
        final title = list.first.title.trim();
        return SpendGroup(
          label: cat != null
              ? _categoryLabels[cat]!
              : (title.isEmpty
                    ? 'Lainnya'
                    : title[0].toUpperCase() + title.substring(1)),
          iconKey: cat ?? pocket.iconKey,
          pocket: pocket,
          count: list.length,
          total: list.fold(0, (s, e) => s + e.amount),
        );
      }(),
  ]..sort((a, b) => b.total.compareTo(a.total));
  return result.take(limit).toList();
}
