import 'types.dart';
import 'views.dart';

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
const _monthLong = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Panjang laporan yang bisa di-export (layar 07).
enum ReportSpan { month, quarter, year }

enum ExportFormat { pdf, excel }

/// Rentang tanggal laporan: [start] inklusif, [end] eksklusif.
class ReportRange {
  const ReportRange(this.span, this.start, this.end);

  /// Rentang yang berakhir di bulan [anchor] (3 bulan = 2 bulan sebelumnya +
  /// bulan ini; setahun = Januari–Desember tahun [anchor]).
  factory ReportRange.of(ReportSpan span, DateTime anchor) {
    final m = DateTime(anchor.year, anchor.month);
    return switch (span) {
      ReportSpan.month => ReportRange(span, m, DateTime(m.year, m.month + 1)),
      ReportSpan.quarter => ReportRange(
        span,
        DateTime(m.year, m.month - 2),
        DateTime(m.year, m.month + 1),
      ),
      ReportSpan.year => ReportRange(
        span,
        DateTime(m.year),
        DateTime(m.year + 1),
      ),
    };
  }

  final ReportSpan span;
  final DateTime start;
  final DateTime end;

  DateTime get lastMonth => DateTime(end.year, end.month - 1);

  /// Bulan-bulan di dalam rentang.
  List<DateTime> get months => [
    for (var d = start; d.isBefore(end); d = DateTime(d.year, d.month + 1)) d,
  ];

  /// "September 2026" / "Juli – September 2026" / "Januari – Desember 2026".
  String get label {
    final last = lastMonth;
    if (span == ReportSpan.month) {
      return '${_monthLong[start.month - 1]} ${start.year}';
    }
    final from = start.year == last.year
        ? _monthLong[start.month - 1]
        : '${_monthLong[start.month - 1]} ${start.year}';
    return '$from – ${_monthLong[last.month - 1]} ${last.year}';
  }

  /// "Sep 2026" / "Jul – Sep 2026" / "2026" (judul pendek).
  String get shortLabel {
    final last = lastMonth;
    return switch (span) {
      ReportSpan.month => '${_monthShort[start.month - 1]} ${start.year}',
      ReportSpan.quarter =>
        start.year == last.year
            ? '${_monthShort[start.month - 1]} – ${_monthShort[last.month - 1]} ${last.year}'
            : '${_monthShort[start.month - 1]} ${start.year} – ${_monthShort[last.month - 1]} ${last.year}',
      ReportSpan.year => '${start.year}',
    };
  }

  /// Nama file: "Laporan_catat_Jul-Sep_2026.pdf".
  String fileName(ExportFormat format) {
    final last = lastMonth;
    final part = switch (span) {
      ReportSpan.month => '${_monthShort[start.month - 1]}_${start.year}',
      ReportSpan.quarter =>
        start.year == last.year
            ? '${_monthShort[start.month - 1]}-${_monthShort[last.month - 1]}_${last.year}'
            : '${_monthShort[start.month - 1]}${start.year}-${_monthShort[last.month - 1]}${last.year}',
      ReportSpan.year => '${start.year}',
    };
    return 'Laporan_catat_$part.${format == ExportFormat.pdf ? 'pdf' : 'xlsx'}';
  }
}

String monthLongName(DateTime d) => _monthLong[d.month - 1];

// ------------------------------------------------------------ data

/// Satu kantong dalam laporan.
class PocketReport {
  const PocketReport({
    required this.pocket,
    required this.spent,
    required this.budget,
  });

  final PocketRef pocket;
  final int spent;

  /// Jatah yang masuk ke kantong ini selama rentang laporan.
  final int budget;
}

/// Ringkasan satu bulan dalam laporan beberapa bulan.
class MonthTotal {
  const MonthTotal(this.month, this.income, this.spent);

  final DateTime month;
  final int income;
  final int spent;
}

/// Satu pengeluaran untuk export.
class ReportExpense {
  const ReportExpense({
    required this.occurredAt,
    required this.title,
    required this.pocket,
    required this.amount,
    required this.source,
    this.merchant,
    this.note,
    this.photoPath,
    this.items = const [],
  });

  final DateTime occurredAt;
  final String title;
  final PocketRef pocket;
  final int amount;
  final ExpenseSource source;
  final String? merchant;
  final String? note;
  final String? photoPath;
  final List<ExpenseLine> items;
}

/// Isi laporan untuk satu rentang (layar 14 & export).
class ReportData {
  const ReportData({
    required this.range,
    required this.mode,
    required this.pockets,
    required this.months,
    required this.expenses,
    required this.incomes,
  });

  final ReportRange range;
  final IncomeMode mode;
  final List<PocketReport> pockets;
  final List<MonthTotal> months;

  /// Terlama dulu.
  final List<ReportExpense> expenses;
  final List<IncomeEntry> incomes;

  int get totalSpent => expenses.fold<int>(0, (s, e) => s + e.amount);
  int get totalIncome => incomes.fold<int>(0, (s, i) => s + i.amount);
  int get remaining => totalIncome - totalSpent;

  /// "Gaji masuk" / "Uang jajan masuk" / "Pemasukan".
  String get incomeLabel => switch (mode) {
    IncomeMode.salary => 'Gaji masuk',
    IncomeMode.allowance => 'Uang jajan masuk',
    IncomeMode.irregular => 'Pemasukan',
  };

  int get recordCount => expenses.length + incomes.length;
}

// ------------------------------------------------------------ insight

/// Satu kalimat insight (kartu di layar 14) + kantong yang dibahas.
class ReportInsight {
  const ReportInsight(this.text, {this.pocket});

  final String text;
  final PocketRef? pocket;
}

/// Bandingkan bulan ini dengan bulan lalu, cari yang paling menarik.
ReportInsight? buildInsight(ReportData current, ReportData? previous) {
  if (current.expenses.isEmpty) return null;
  final prevMonth = monthLongName(
    current.range.start.subtract(const Duration(days: 1)),
  );
  final prevSpent = {
    for (final p in previous?.pockets ?? const <PocketReport>[])
      p.pocket.id: p.spent,
  };

  PocketReport? top;
  var topRise = 0.0;
  for (final p in current.pockets) {
    final before = prevSpent[p.pocket.id] ?? 0;
    if (before <= 0 || p.spent <= before) continue;
    final rise = (p.spent - before) / before;
    if (rise >= 0.05 && rise > topRise) {
      top = p;
      topRise = rise;
    }
  }
  if (top != null) {
    final favorite = _favoriteTitle(current.expenses, top.pocket.id);
    final pct = (topRise * 100).round();
    final noun = top.pocket.type == PocketType.keinginan
        ? 'Jajan'
        : 'Pengeluaran';
    return ReportInsight(
      '$noun ${top.pocket.name} naik $pct% dari $prevMonth.'
      '${favorite == null ? '' : ' $favorite jadi juaranya.'}',
      pocket: top.pocket,
    );
  }

  final prevTotal = previous?.totalSpent ?? 0;
  if (prevTotal > 0 && current.totalSpent < prevTotal) {
    final pct = ((prevTotal - current.totalSpent) * 100 / prevTotal).round();
    if (pct >= 1) {
      return ReportInsight(
        'Pengeluaran turun $pct% dari $prevMonth. Mantap, pertahankan!',
      );
    }
  }

  final biggest = current.expenses.reduce(
    (a, b) => b.amount > a.amount ? b : a,
  );
  // Judul bawaan catat manual tanpa nama = "Pengeluaran"; jangan diulang.
  final label = [biggest.merchant, biggest.title]
      .map((s) => s?.trim() ?? '')
      .firstWhere(
        (s) => s.isNotEmpty && s.toLowerCase() != 'pengeluaran',
        orElse: () => '',
      );
  return ReportInsight(
    label.isEmpty
        ? 'Pengeluaran terbesar bulan ini ada di kantong '
              '${biggest.pocket.name}.'
        : 'Pengeluaran terbesar: $label di kantong ${biggest.pocket.name}.',
    pocket: biggest.pocket,
  );
}

/// Judul yang paling sering muncul di satu kantong (seri → nominal terbesar).
String? _favoriteTitle(List<ReportExpense> expenses, String pocketId) {
  final count = <String, int>{};
  final sum = <String, int>{};
  for (final e in expenses.where((e) => e.pocket.id == pocketId)) {
    final key = e.title.trim();
    if (key.isEmpty) continue;
    count[key] = (count[key] ?? 0) + 1;
    sum[key] = (sum[key] ?? 0) + e.amount;
  }
  if (count.isEmpty) return null;
  final best = count.keys.reduce((a, b) {
    final byCount = count[b]!.compareTo(count[a]!);
    if (byCount != 0) return byCount > 0 ? b : a;
    return sum[b]! > sum[a]! ? b : a;
  });
  return best[0].toUpperCase() + best.substring(1);
}
