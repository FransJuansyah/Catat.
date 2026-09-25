import '../core/models/pocket.dart';
import '../core/theme/tokens.dart';

/// Data contoh sesuai desain Figma (sementara, sebelum Supabase).
abstract final class DemoData {
  static const userName = 'Frans';
  static const salary = 6500000;

  static final pockets = [
    Pocket.withDefaultStyle(
      id: 'wajib',
      type: PocketType.wajib,
      allocation: 3250000,
      spent: 2800000,
    ),
    Pocket.withDefaultStyle(
      id: 'darurat',
      type: PocketType.darurat,
      allocation: 1300000,
      spent: 0,
    ),
    Pocket.withDefaultStyle(
      id: 'keinginan',
      type: PocketType.keinginan,
      allocation: 1950000,
      spent: 1520000,
    ),
  ];

  static int get remaining => pockets.fold(0, (sum, p) => sum + p.remaining);
}
