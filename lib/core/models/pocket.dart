import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Satu kantong. `type` tetap; nama/ikon/warna boleh dikustom user.
class Pocket {
  const Pocket({
    required this.id,
    required this.type,
    required this.name,
    required this.icon,
    required this.color,
    required this.soft,
    required this.allocation,
    required this.spent,
  });

  factory Pocket.withDefaultStyle({
    required String id,
    required PocketType type,
    required int allocation,
    required int spent,
  }) {
    final s = PocketStyle.defaults[type]!;
    return Pocket(
      id: id,
      type: type,
      name: s.defaultName,
      icon: s.icon,
      color: s.color,
      soft: s.soft,
      allocation: allocation,
      spent: spent,
    );
  }

  final String id;
  final PocketType type;
  final String name;
  final IconData icon;
  final Color color;
  final Color soft;
  final int allocation;
  final int spent;

  int get remaining => allocation - spent;
  double get usedRatio =>
      allocation == 0 ? 0 : (spent / allocation).clamp(0, 1).toDouble();
}
