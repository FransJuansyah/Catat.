import 'package:flutter/material.dart';

import '../format.dart';
import '../models/pocket.dart';
import '../theme/tokens.dart';
import 'icon_badge.dart';
import 'progress_track.dart';

/// Kartu kantong di Beranda (desain layar 03).
class PocketCard extends StatelessWidget {
  const PocketCard({super.key, required this.pocket, this.onTap});

  final Pocket pocket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final untouched = pocket.spent == 0;
    final status = untouched
        ? 'Aman, ${rupiahShort(pocket.remaining)}'
        : 'Sisa ${rupiahShort(pocket.remaining)}';

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
                icon: pocket.icon,
                background: pocket.soft,
                color: pocket.color,
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
                            color: untouched ? pocket.color : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressTrack(value: pocket.usedRatio, color: pocket.color),
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
