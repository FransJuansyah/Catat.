import 'package:flutter/material.dart';

import '../../domain/home_summary.dart';
import '../format.dart';
import '../theme/tokens.dart';
import 'icon_badge.dart';
import 'progress_track.dart';

/// Kartu kantong di Beranda (desain layar 03).
class PocketCard extends StatelessWidget {
  const PocketCard({super.key, required this.pocket, this.onTap});

  final PocketView pocket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(pocket.color);
    final balance = pocket.balance;
    final untouched = balance.spent == 0;
    // Dipakai melebihi jatah: tulisan & bar merah, bukan "Sisa -Rp …".
    final minus = balance.remaining < 0;
    final status = minus
        ? 'Minus ${rupiahShort(-balance.remaining)}'
        : untouched
        ? 'Aman, ${rupiahShort(balance.remaining)}'
        : 'Sisa ${rupiahShort(balance.remaining)}';
    final statusColor = minus
        ? AppColors.danger
        : untouched
        ? color
        : AppColors.muted;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.cardPadSm),
          child: Row(
            children: [
              IconBadge(
                icon: PocketVisuals.icon(pocket.iconKey),
                background: PocketVisuals.soft(color),
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pocket.name,
                            style: AppText.style(15, AppText.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          status,
                          style: AppText.style(
                            13,
                            AppText.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressTrack(
                      value: balance.usedRatio,
                      color: minus ? AppColors.danger : color,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
