import 'dart:math' as math;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Tanggal gajian di bulan tertentu. Tanggal 29–31 dijepit ke hari terakhir
/// bulan pendek (mis. gajian tgl 31 → 28/29 Februari).
DateTime paydayIn(int year, int month, int payday) {
  final normalized = DateTime(year, month);
  return DateTime(
    normalized.year,
    normalized.month,
    math.min(payday, daysInMonth(normalized.year, normalized.month)),
  );
}

/// Satu siklus gaji: mulai di hari gajian, selesai sehari sebelum gajian berikutnya.
class PayPeriod {
  const PayPeriod(this.start, this.end);

  /// Periode yang memuat [date] untuk tanggal gajian [payday] (1–31).
  factory PayPeriod.containing(DateTime date, int payday) {
    assert(payday >= 1 && payday <= 31, 'payday harus 1–31');
    final d = dateOnly(date);
    final thisMonth = paydayIn(d.year, d.month, payday);
    final start = d.isBefore(thisMonth)
        ? paydayIn(d.year, d.month - 1, payday)
        : thisMonth;
    final next = paydayIn(start.year, start.month + 1, payday);
    return PayPeriod(start, DateTime(next.year, next.month, next.day - 1));
  }

  /// Hari pertama (inklusif), jam 00:00 waktu lokal.
  final DateTime start;

  /// Hari terakhir (inklusif), jam 00:00 waktu lokal.
  final DateTime end;

  DateTime get nextPayday => DateTime(end.year, end.month, end.day + 1);

  int get lengthInDays => _daysBetween(start, nextPayday);

  bool contains(DateTime date) {
    final d = dateOnly(date);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  /// 0 = hari ini gajian berikutnya, 1 = besok, dst.
  int daysUntilNextPayday(DateTime today) =>
      _daysBetween(dateOnly(today), nextPayday);

  /// Porsi periode yang sudah berjalan (0..1), menghitung hari ini sebagai sudah berjalan.
  double elapsedRatio(DateTime today) {
    final elapsed = _daysBetween(start, dateOnly(today)) + 1;
    return (elapsed / lengthInDays).clamp(0, 1).toDouble();
  }

  // Dibulatkan per jam agar aman dari pergeseran DST di zona waktu lain.
  static int _daysBetween(DateTime a, DateTime b) =>
      (b.difference(a).inHours / 24).round();

  @override
  bool operator ==(Object other) =>
      other is PayPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PayPeriod($start – $end)';
}
