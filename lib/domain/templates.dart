import 'types.dart';

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

  static const all = [klasik, anakKos, pejuangNabung];
}
