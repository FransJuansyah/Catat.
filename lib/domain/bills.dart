import 'dart:math' as math;

/// Tagihan berulang tiap bulan (layar 69–71).
/// - cicilan: ada akhirnya ([Bill.remaining] kali lagi), mis. cicilan HP.
/// - rutin: terus tiap bulan, mis. kos, Spotify, kartu kredit.
enum BillKind { cicilan, rutin }

/// Bulan sebagai satu angka (tahun × 12 + bulan − 1) supaya gampang dihitung.
int monthIndex(DateTime d) => d.year * 12 + d.month - 1;

DateTime _monthStart(int index) => DateTime(index ~/ 12, index % 12 + 1);

/// Tanggal jatuh tempo di bulan [index]; tanggal 31 di bulan pendek jadi
/// hari terakhir bulan itu.
DateTime dueDateIn(int index, int dueDay) {
  final start = _monthStart(index);
  final last = DateTime(start.year, start.month + 1, 0).day;
  return DateTime(start.year, start.month, math.min(dueDay, last));
}

/// Bulan jatuh tempo pertama untuk tagihan yang baru dibuat [today]: bulan ini
/// kalau tanggalnya belum lewat, selain itu bulan depan.
int firstDueMonth(int dueDay, DateTime today) {
  final now = monthIndex(today);
  final due = dueDateIn(now, dueDay);
  final day = DateTime(today.year, today.month, today.day);
  return day.isAfter(due) ? now + 1 : now;
}

class Bill {
  const Bill({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.amount,
    required this.dueDay,
    required this.kind,
    required this.startMonth,
    required this.paidThrough,
    this.remaining,
    this.pocketId,
    this.remind = true,
  });

  final String id;
  final String name;
  final String iconKey;
  final int amount;

  /// Tanggal bayar tiap bulan (1–31).
  final int dueDay;
  final BillKind kind;

  /// Cicilan: sisa berapa kali bayar lagi. null untuk tagihan rutin.
  final int? remaining;
  final String? pocketId;
  final bool remind;

  /// Bulan jatuh tempo pertama ([monthIndex]).
  final int startMonth;

  /// Sudah dibayar sampai bulan ini ([monthIndex]); awalnya startMonth − 1.
  final int paidThrough;

  bool get finished => kind == BillKind.cicilan && (remaining ?? 0) <= 0;

  /// Bulan tagihan berikutnya yang belum dibayar.
  int get nextMonth => math.max(paidThrough + 1, startMonth);

  DateTime get nextDue => dueDateIn(nextMonth, dueDay);

  /// Cicilan: bulan pembayaran terakhir.
  int? get lastMonth => kind == BillKind.cicilan && remaining != null
      ? nextMonth + remaining! - 1
      : null;

  /// Hari menuju jatuh tempo berikutnya (negatif = telat).
  int daysLeft(DateTime today) =>
      nextDue.difference(DateTime(today.year, today.month, today.day)).inDays;

  /// Ada tagihan di bulan [index] (sudah mulai & belum lunas semua sebelumnya).
  bool activeIn(int index) =>
      index >= startMonth && !(finished && paidThrough < index);

  bool paidIn(int index) => paidThrough >= index;
}

/// Ringkasan layar Tagihan & cicilan (69).
class BillsSummary {
  const BillsSummary({
    required this.total,
    required this.paid,
    required this.unpaid,
    required this.done,
  });

  /// Total tagihan bulan ini & yang sudah lunas.
  final int total;
  final int paid;

  /// Belum dibayar, jatuh tempo terdekat dulu (termasuk yang telat).
  final List<Bill> unpaid;

  /// Sudah lunas bulan ini.
  final List<Bill> done;

  int get count => unpaid.length + done.length;
}

BillsSummary summarizeBills(Iterable<Bill> bills, DateTime today) {
  final now = monthIndex(today);
  final unpaid = <Bill>[], done = <Bill>[];
  for (final b in bills) {
    if (b.finished && !b.paidIn(now)) continue;
    // Baru mulai bulan depan, belum dibayar bulan ini, atau telat → belum.
    if (b.startMonth > now || !b.paidIn(now)) {
      unpaid.add(b);
    } else {
      done.add(b);
    }
  }
  unpaid.sort((a, b) => a.nextDue.compareTo(b.nextDue));
  done.sort((a, b) => a.dueDay.compareTo(b.dueDay));
  int sum(Iterable<Bill> l) => l.fold(0, (s, b) => s + b.amount);
  final thisMonth = unpaid.where((b) => b.nextMonth <= now);
  return BillsSummary(
    total: sum(thisMonth) + sum(done),
    paid: sum(done),
    unpaid: unpaid,
    done: done,
  );
}

/// Tagihan yang perlu diingatkan di Beranda (≤ [days] hari lagi atau telat).
List<Bill> dueSoon(Iterable<Bill> bills, DateTime today, {int days = 3}) {
  final list = [
    for (final b in bills)
      if (!b.finished && b.daysLeft(today) <= days) b,
  ]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  return list;
}

/// Label status singkat: "Telat 2 hari", "Hari ini", "Besok", "6 hari lagi".
String dueLabel(int days) => switch (days) {
  < 0 => 'Telat ${-days} hari',
  0 => 'Hari ini',
  1 => 'Besok',
  _ => '$days hari lagi',
};

/// Total cicilan & tagihan per bulan dibanding pemasukan. Batas aman 30%.
const safeBillRatio = 0.3;

int monthlyBillTotal(Iterable<Bill> bills) =>
    bills.where((b) => !b.finished).fold(0, (s, b) => s + b.amount);

/// Nama bulan singkat untuk "Lunas Mei 2027".
const _months = [
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

String monthLabel(int index) {
  final d = _monthStart(index);
  return '${_months[d.month - 1]} ${d.year}';
}
