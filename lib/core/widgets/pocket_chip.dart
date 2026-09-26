import 'package:flutter/material.dart';

import '../../domain/home_summary.dart';
import '../theme/tokens.dart';

/// Pilihan kantong berbentuk pil (Catat Manual, Sesuaikan Saldo, Hapus
/// Kantong) atau pilihan Jenis kantong (layar 21).
class PocketChip extends StatelessWidget {
  PocketChip({
    super.key,
    required PocketView pocket,
    required this.selected,
    required this.onTap,
  }) : label = pocket.name,
       icon = PocketVisuals.icon(pocket.iconKey),
       color = Color(pocket.color);

  const PocketChip.raw({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : AppColors.card,
      shape: StadiumBorder(
        side: selected
            ? BorderSide.none
            : const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(
                    13,
                    AppText.w800,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Susun [children] sama lebar, maksimal [perRow] per baris. Dipakai untuk
/// pilihan kantong (2–6 kantong) supaya tetap muat di layar HP.
class ChipRows extends StatelessWidget {
  const ChipRows({
    super.key,
    required this.children,
    this.perRow = 3,
    this.gap = 8,
  });

  final List<Widget> children;
  final int perRow;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[
      for (var i = 0; i < children.length; i += perRow)
        children.sublist(i, (i + perRow).clamp(0, children.length)),
    ];
    // Baris terakhir yang kurang tetap selebar kolom baris penuh.
    final columns = children.length < perRow ? children.length : perRow;
    return Column(
      children: [
        for (final (r, row) in rows.indexed) ...[
          if (r > 0) SizedBox(height: gap),
          Row(
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: gap),
                Expanded(
                  child: c < row.length ? row[c] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
