import 'bills.dart';
import 'home_summary.dart';
import 'types.dart';

/// Simulasi kredit barang (layar 72). Bunga flat seperti kredit HP/motor:
/// bunga dihitung dari pokok pinjaman (harga − DP) tiap bulan, tidak menurun.
/// AI hanya membaca angkanya; hitungannya di sini supaya pasti benar.
class InstallmentSim {
  const InstallmentSim({
    required this.item,
    required this.price,
    required this.dp,
    required this.months,
    required this.ratePercent,
    this.perYear = false,
  });

  /// Nama barang, mis. "HP".
  final String item;
  final int price;
  final int dp;
  final int months;

  /// Bunga dalam persen (2 = 2%), per bulan atau per tahun ([perYear]).
  final double ratePercent;
  final bool perYear;

  int get principal => price - dp;

  /// Total bunga selama [months] bulan.
  int get interest {
    final perMonth = perYear ? ratePercent / 12 : ratePercent;
    return (principal * perMonth / 100 * months).round();
  }

  /// Cicilan per bulan, dibulatkan ke atas (biar tidak kurang bayar).
  int get monthly => ((principal + interest) / months).ceil();

  /// Total uang keluar = DP + pokok + bunga.
  int get total => price + interest;

  InstallmentSim withMonths(int m) => InstallmentSim(
    item: item,
    price: price,
    dp: dp,
    months: m,
    ratePercent: ratePercent,
    perYear: perYear,
  );

  /// Tenor pembanding untuk tombol "Coba …".
  int get altMonths => months == 6 ? 12 : 6;

  /// "2% per bulan" / "12% per tahun" / "tanpa bunga".
  String get rateLabel {
    if (ratePercent == 0) return 'tanpa bunga';
    final r = ratePercent == ratePercent.roundToDouble()
        ? ratePercent.toStringAsFixed(0)
        : ratePercent.toStringAsFixed(1).replaceAll('.', ',');
    return '$r% per ${perYear ? 'tahun' : 'bulan'}';
  }
}

/// Perkiraan pemasukan sebulan dari Beranda (untuk "x% dari gajimu").
/// 0 = tidak diketahui (penghasilan tidak tetap yang belum ada catatan).
int monthlyIncomeOf(HomeSummary s) => switch (s.mode) {
  IncomeMode.irregular => s.monthIncome,
  _ => switch (s.perNoun) {
    'hari' => s.salary * 30,
    'minggu' => (s.salary * 52 / 12).round(),
    _ => s.salary,
  },
};

/// Dampak cicilan/tagihan baru: persen dari pemasukan & total semua cicilan.
class BillImpact {
  const BillImpact({required this.share, required this.totalShare});

  /// Bagian yang baru saja ditambah.
  final double share;

  /// Semua tagihan (lama + baru) dibanding pemasukan.
  final double totalShare;

  bool get safe => totalShare <= safeBillRatio;

  static BillImpact? of(int added, Iterable<Bill> existing, int income) {
    if (income <= 0) return null;
    final total = monthlyBillTotal(existing) + added;
    return BillImpact(share: added / income, totalShare: total / income);
  }

  static String pct(double v) => '${(v * 100).round()}%';
}
