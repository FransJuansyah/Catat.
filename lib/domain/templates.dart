import 'pocket_config.dart';
import 'types.dart';

/// Warna kantong yang bisa dipilih user (layar 21), ARGB. Sumber untuk
/// `PocketVisuals.palette`.
const pocketPalette = [
  0xFF6D5DFC,
  0xFF12A36B,
  0xFFFF4F7B,
  0xFFFF8A00,
  0xFF0EA5E9,
  0xFFEAB308,
  0xFF0E0E10,
];

/// Ikon yang bisa dipilih untuk kantong (layar 21, 4 kolom). Urutan ini juga
/// dipakai untuk ikon kantong baru.
const pocketIconChoices = [
  'house',
  'shield',
  'sparkles',
  'coffee',
  'food',
  'piggy',
  'plane',
  'gamepad',
  'music',
  'gift',
  'heart',
  'shirt',
  'bag',
  'car',
  'phone',
  'film',
];

/// Kantong awal dari sebuah template (layar 19).
class PocketSeed {
  const PocketSeed(
    this.type,
    this.name,
    this.iconKey,
    this.color,
    this.percent,
  );

  final PocketType type;
  final String name;
  final String iconKey;
  final int color;
  final int percent;
}

class PocketTemplate {
  const PocketTemplate(this.name, this.pockets);

  final String name;
  final List<PocketSeed> pockets;
}

abstract final class PocketTemplates {
  static const klasik = PocketTemplate('Klasik 50/20/30', [
    PocketSeed(PocketType.wajib, 'Wajib', 'house', 0xFF6D5DFC, 50),
    PocketSeed(PocketType.darurat, 'Darurat', 'shield', 0xFF12A36B, 20),
    PocketSeed(PocketType.keinginan, 'Keinginan', 'sparkles', 0xFFFF4F7B, 30),
  ]);

  static const anakKos = PocketTemplate('Anak Kos', [
    PocketSeed(PocketType.wajib, 'Kos & Makan', 'house', 0xFFFF8A00, 60),
    PocketSeed(PocketType.darurat, 'Tabungan', 'shield', 0xFF0EA5E9, 15),
    PocketSeed(PocketType.keinginan, 'Nongkrong', 'coffee', 0xFFFF4F7B, 25),
  ]);

  static const pejuangNabung = PocketTemplate('Pejuang Nabung', [
    PocketSeed(PocketType.wajib, 'Kebutuhan', 'house', 0xFF6D5DFC, 45),
    PocketSeed(PocketType.darurat, 'Tabungan', 'shield', 0xFF12A36B, 35),
    PocketSeed(PocketType.keinginan, 'Self-reward', 'gift', 0xFFEAB308, 20),
  ]);

  static const pelajar = PocketTemplate('Pelajar', [
    PocketSeed(PocketType.wajib, 'Jajan & Makan', 'food', 0xFFFF8A00, 50),
    PocketSeed(PocketType.darurat, 'Tabungan', 'piggy', 0xFF0EA5E9, 20),
    PocketSeed(
      PocketType.keinginan,
      'Seneng-seneng',
      'sparkles',
      0xFFFF4F7B,
      30,
    ),
  ]);

  /// Dana darurat lebih besar karena ada masa sepi order.
  static const freelancer = PocketTemplate('Freelancer', [
    PocketSeed(PocketType.wajib, 'Kebutuhan', 'house', 0xFF6D5DFC, 50),
    PocketSeed(PocketType.darurat, 'Dana Darurat', 'shield', 0xFF12A36B, 30),
    PocketSeed(PocketType.keinginan, 'Keinginan', 'sparkles', 0xFFFF4F7B, 20),
  ]);

  static const all = [klasik, anakKos, pejuangNabung, pelajar, freelancer];

  /// Nama template hasil "Bikin sendiri" (layar 43).
  static const customName = 'Bikin sendiri';

  /// Template dari kantong yang disusun user sendiri (layar 43). Jatah
  /// selalu disimpan sebagai persen dari [base], dirapikan supaya pas 100%
  /// (jatah nominal bisa meleset karena pembulatan).
  static PocketTemplate custom(List<PocketConfig> pockets, int base) {
    final percents = balancePockets([
      for (final p in pockets) p.withMode(AllocationMode.percent, base),
    ], base);
    return PocketTemplate(customName, [
      for (final p in percents)
        PocketSeed(p.type, p.name.trim(), p.iconKey, p.color, p.percent),
    ]);
  }

  /// Pilihan template di layar 19 sesuai tipe pemasukan; yang pertama = default.
  static List<PocketTemplate> forMode(IncomeMode mode) => switch (mode) {
    IncomeMode.salary => const [klasik, anakKos, pejuangNabung],
    IncomeMode.allowance => const [pelajar, anakKos, klasik],
    IncomeMode.irregular => const [freelancer, klasik, pejuangNabung],
  };
}
