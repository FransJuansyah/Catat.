import 'allocation.dart';
import 'pocket_balance.dart';
import 'types.dart';

/// Data satu kantong untuk ditampilkan.
class PocketView {
  const PocketView({
    required this.id,
    required this.type,
    required this.name,
    required this.iconKey,
    required this.color,
    required this.balance,
    this.mode = AllocationMode.percent,
    this.percent = 0,
    this.nominal = 0,
    this.lowThresholdPercent = 20,
  });

  final String id;
  final PocketType type;
  final String name;
  final String iconKey;

  /// ARGB, mis. 0xFF6D5DFC.
  final int color;
  final PocketBalance balance;

  /// Aturan bagi (untuk preview pembagian pemasukan, layar 30).
  final AllocationMode mode;
  final int percent;
  final int nominal;

  /// Ambang peringatan hampir habis (0 = mati).
  final int lowThresholdPercent;

  /// Sisa di bawah ambang → peringatan (layar 24).
  bool get isLow =>
      lowThresholdPercent > 0 &&
      balance.isLow(thresholdPercent: lowThresholdPercent);

  PocketRule get rule =>
      PocketRule(pocketId: id, mode: mode, percent: percent, nominal: nominal);
}

/// Semua yang dibutuhkan layar Beranda (layar 03, 32, 33).
class HomeSummary {
  const HomeSummary({
    required this.userName,
    required this.mode,
    required this.salary,
    required this.pockets,
    required this.daysToPayday,
    required this.onTrack,
    required this.hint,
    this.periodNoun = 'bulan ini',
    this.perNoun = 'bulan',
    this.monthIncome = 0,
    this.dailySafe,
    this.dailySafeUntil,
    this.opening,
  });

  final String userName;
  final IncomeMode mode;

  /// Pemasukan otomatis periode ini (gaji / uang jajan). 0 untuk tidak tetap.
  final int salary;
  final List<PocketView> pockets;
  final int daysToPayday;
  final bool onTrack;

  /// Teks di bawah sapaan, mis. "Gajian besok, tahan dulu ya".
  final String hint;

  /// "bulan ini" / "minggu ini" / "hari ini".
  final String periodNoun;

  /// "bulan" / "minggu" / "hari".
  final String perNoun;

  /// Total pemasukan bulan kalender ini (penghasilan tidak tetap).
  final int monthIncome;

  /// Jatah aman per hari sampai pemasukan berikutnya (uang jajan).
  final int? dailySafe;

  /// Label batas jatah harian, mis. "Senin" atau "tgl 25".
  final String? dailySafeUntil;

  /// Saldo awal saat baru daftar (layar 42), hanya di periode pertama.
  final int? opening;

  int get remaining => pockets.fold<int>(0, (s, p) => s + p.balance.remaining);

  /// Total jatah periode ini (pemasukan + pindah saldo).
  int get available => pockets.fold<int>(0, (s, p) => s + p.balance.available);

  /// Isi "baterai" duit (layar 59): sisa ÷ jatah, 0..1.
  double get level =>
      available <= 0 ? 0 : (remaining / available).clamp(0.0, 1.0);
}
