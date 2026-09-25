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
  });

  final String id;
  final PocketType type;
  final String name;
  final String iconKey;

  /// ARGB, mis. 0xFF6D5DFC.
  final int color;
  final PocketBalance balance;
}

/// Semua yang dibutuhkan layar Beranda (layar 03).
class HomeSummary {
  const HomeSummary({
    required this.userName,
    required this.salary,
    required this.pockets,
    required this.daysToPayday,
    required this.onTrack,
  });

  final String userName;
  final int salary;
  final List<PocketView> pockets;
  final int daysToPayday;
  final bool onTrack;

  int get remaining => pockets.fold<int>(0, (s, p) => s + p.balance.remaining);
}
