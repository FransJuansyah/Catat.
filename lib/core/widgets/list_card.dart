import 'package:flutter/material.dart';

import '../../domain/views.dart';
import '../format.dart';
import '../theme/tokens.dart';
import 'icon_badge.dart';

/// Kartu putih berisi baris-baris dengan garis pemisah.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children, this.vertical = 4});

  final List<Widget> children;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: vertical),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.line),
            child,
          ],
        ],
      ),
    );
  }
}

/// Baris satu pengeluaran: ikon, judul, keterangan, nominal.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.entry,
    required this.subtitle,
    this.useCategoryIcon = false,
    this.onTap,
  });

  final ExpenseEntry entry;
  final Widget subtitle;

  /// `true` = ikon kategori (layar 12), `false` = ikon kantong (layar 06).
  final bool useCategoryIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(entry.pocket.color);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            IconBadge(
              icon: PocketVisuals.icon(
                useCategoryIcon ? entry.iconKey : entry.pocket.iconKey,
              ),
              background: PocketVisuals.soft(color),
              color: color,
              size: 40,
              iconSize: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.style(15, AppText.w800),
                  ),
                  const SizedBox(height: 3),
                  subtitle,
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              rupiahOut(entry.amount),
              style: AppText.style(15, AppText.w800),
            ),
          ],
        ),
      ),
    );
  }
}
