/// Saldo satu kantong dalam satu periode.
class PocketBalance {
  const PocketBalance({
    required this.allocation,
    this.spent = 0,
    this.transferIn = 0,
    this.transferOut = 0,
  });

  final int allocation;
  final int spent;
  final int transferIn;
  final int transferOut;

  /// Jatah setelah pindah saldo.
  int get available => allocation + transferIn - transferOut;

  int get remaining => available - spent;

  /// Porsi terpakai (0..1) untuk progress bar.
  double get usedRatio {
    if (available <= 0) return spent > 0 ? 1 : 0;
    return (spent / available).clamp(0, 1).toDouble();
  }

  /// Sisa di bawah ambang (default 20%) → tampilkan peringatan (layar 24).
  bool isLow({int thresholdPercent = 20}) =>
      available > 0 && remaining * 100 < available * thresholdPercent;
}

/// "On track" jika porsi uang terpakai tidak melebihi porsi waktu periode
/// yang sudah berjalan (+10% toleransi).
bool isOnTrack({
  required int spent,
  required int budget,
  required double elapsedRatio,
}) {
  if (budget <= 0) return spent == 0;
  return spent / budget <= elapsedRatio + 0.10;
}
