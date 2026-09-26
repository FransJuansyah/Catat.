import 'pay_period.dart';
import 'types.dart';

/// Aturan kapan pemasukan otomatis masuk, sesuai tipe user.
class IncomeSchedule {
  const IncomeSchedule({
    required this.mode,
    this.frequency = IncomeFrequency.monthly,
    this.payday = 25,
    this.weekday = 1,
  });

  final IncomeMode mode;
  final IncomeFrequency frequency;

  /// Tanggal (1–31) untuk siklus bulanan.
  final int payday;

  /// Hari (1 = Senin … 7 = Minggu) untuk siklus mingguan.
  final int weekday;

  /// Pemasukan tidak tetap → saldo kantong terus berjalan, tanpa jatah periode.
  bool get isRunningBalance => mode == IncomeMode.irregular;

  IncomeFrequency get effectiveFrequency =>
      mode == IncomeMode.salary ? IncomeFrequency.monthly : frequency;

  /// Periode yang memuat [date].
  PayPeriod periodFor(DateTime date) {
    if (mode == IncomeMode.irregular) return PayPeriod.calendarMonth(date);
    return switch (effectiveFrequency) {
      IncomeFrequency.daily => PayPeriod.daily(date),
      IncomeFrequency.weekly => PayPeriod.weekly(date, weekday),
      IncomeFrequency.monthly => PayPeriod.containing(date, payday),
    };
  }

  /// "bulan ini" / "minggu ini" / "hari ini".
  String get periodNoun => switch ((mode, effectiveFrequency)) {
    (IncomeMode.irregular, _) => 'bulan ini',
    (_, IncomeFrequency.daily) => 'hari ini',
    (_, IncomeFrequency.weekly) => 'minggu ini',
    _ => 'bulan ini',
  };

  /// "/ minggu" dll. untuk teks "dari Rp 350.000 / minggu".
  String get perNoun => switch (effectiveFrequency) {
    IncomeFrequency.daily => 'hari',
    IncomeFrequency.weekly => 'minggu',
    IncomeFrequency.monthly => 'bulan',
  };
}

const _dayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

String weekdayName(int weekday) => _dayNames[weekday - 1];

/// Teks di bawah sapaan Beranda tentang pemasukan berikutnya.
String nextIncomeHint(IncomeSchedule s, int days, DateTime nextDate) {
  if (s.mode == IncomeMode.salary) {
    return switch (days) {
      0 => 'Hari ini gajian, asik!',
      1 => 'Gajian besok, tahan dulu ya',
      _ => 'Gajian $days hari lagi',
    };
  }
  if (s.effectiveFrequency == IncomeFrequency.daily) {
    return 'Uang jajan masuk lagi besok';
  }
  return switch (days) {
    0 => 'Uang jajan masuk hari ini',
    1 => 'Uang jajan masuk besok',
    _ =>
      s.effectiveFrequency == IncomeFrequency.weekly
          ? 'Uang jajan masuk ${weekdayName(nextDate.weekday)}, $days hari lagi'
          : 'Uang jajan masuk tgl ${nextDate.day}, $days hari lagi',
  };
}
