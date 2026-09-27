/// Fitur yang terkunci setelah trial habis (catat. Pro, layar 53).
enum ProFeature { scan, autoCapture, export }

/// Status catat. Pro: trial 7 hari sejak selesai daftar, lalu sekali bayar
/// untuk selamanya. Catat manual, kantong & laporan di layar selalu gratis.
class ProStatus {
  const ProStatus({this.trialStart, this.purchasedAt, required this.now});

  static const trialDays = 7;

  /// Mulai trial (selesai daftar / update ke versi berbayar). null = belum
  /// daftar → belum dikunci.
  final DateTime? trialStart;

  /// Sudah beli (sekali bayar, selamanya).
  final DateTime? purchasedAt;
  final DateTime now;

  bool get purchased => purchasedAt != null;

  DateTime? get trialEnd => trialStart?.add(const Duration(days: trialDays));

  /// Jam HP dimundurkan jauh sebelum trial dimulai → dianggap habis.
  bool get _clockTampered =>
      trialStart != null &&
      now.isBefore(trialStart!.subtract(const Duration(days: 1)));

  bool get inTrial {
    final end = trialEnd;
    if (purchased || end == null || _clockTampered) return false;
    return now.isBefore(end);
  }

  bool get trialOver => !purchased && trialStart != null && !inTrial;

  /// Fitur Pro boleh dipakai.
  bool get unlocked => purchased || trialStart == null || inTrial;

  /// Sisa hari trial, dibulatkan ke atas (7 … 1). 0 = habis / sudah beli.
  int get daysLeft {
    if (!inTrial) return 0;
    final hours = trialEnd!.difference(now).inHours;
    return (hours / 24).ceil().clamp(1, trialDays);
  }
}
