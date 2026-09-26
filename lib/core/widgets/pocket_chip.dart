import 'package:flutter/material.dart';

import '../../domain/home_summary.dart';
import '../theme/tokens.dart';

/// Pilihan kantong berbentuk pil (Catat Manual, Sesuaikan Saldo).
class PocketChip extends StatelessWidget {
  const PocketChip({
    super.key,
    required this.pocket,
    required this.selected,
    required this.onTap,
  });

  final PocketView pocket;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(pocket.color);
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
              Icon(
                PocketVisuals.icon(pocket.iconKey),
                size: 16,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  pocket.name,
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
