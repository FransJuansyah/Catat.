import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../theme/tokens.dart';

/// Pil "Sep 2026 ⌄" di kanan atas Catatan & Laporan.
class MonthPill extends StatelessWidget {
  const MonthPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppText.style(13, AppText.w800)),
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: AppColors.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet pilih bulan. `null` = batal.
Future<DateTime?> showMonthSheet(
  BuildContext context, {
  required List<DateTime> months,
  required DateTime selected,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.disabledBg,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in months)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        monthYearLong(m),
                        style: AppText.style(
                          15,
                          m == selected ? AppText.w800 : AppText.w500,
                        ),
                      ),
                      trailing: m == selected
                          ? const Icon(
                              LucideIcons.check,
                              size: 18,
                              color: AppColors.ink,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, m),
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
