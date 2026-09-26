import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/pocket_chip.dart';
import '../../domain/allocation.dart';
import '../../domain/templates.dart';

/// Kartu "Dibagi ke N kantong": bar persen + nama & nominal (layar 02, 28, 29,
/// 42). [amount] 0 → hanya persen yang ditampilkan. Maksimal 3 kantong per
/// baris supaya 4–6 kantong tetap terbaca.
class SplitPreviewCard extends StatelessWidget {
  const SplitPreviewCard({
    super.key,
    required this.template,
    this.amount = 0,
    this.title,
  });

  final PocketTemplate template;
  final int amount;

  /// Judul kecil di dalam kartu (layar 42).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final pockets = template.pockets;
    final amounts = allocateAll(amount, [
      for (final (i, p) in pockets.indexed)
        PocketRule(pocketId: '$i', percent: p.percent),
    ]);
    return Container(
      padding: const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AppText.style(13, AppText.w700, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
          ],
          SplitBar(parts: [for (final p in pockets) (p.percent, p.color)]),
          const SizedBox(height: 14),
          ChipRows(
            gap: 12,
            children: [
              for (final (i, p) in pockets.indexed)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Color(p.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.style(
                              12,
                              AppText.w500,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        amount == 0
                            ? '${p.percent}%'
                            : '${p.percent}% · ${rupiahShort(amounts['$i']!).substring(3)}',
                        style: AppText.style(15, AppText.w800),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Judul bagian + tautan kecil di kanan ("Dibagi ke 3 kantong · Ubah").
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppText.style(17, AppText.w800, spacingPercent: -1),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: AppText.style(12, AppText.w700, color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}

/// Baris pengaturan dalam kartu putih: ikon, judul (+ sub), dan kontrol kanan.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            IconBadge(
              icon: icon,
              background: AppColors.bg,
              color: AppColors.ink,
              size: 36,
              iconSize: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.style(15, AppText.w700)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppText.style(
                        12,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Nominal besar yang bisa diketuk untuk diubah (layar 02, 28).
class EditableAmount extends StatelessWidget {
  const EditableAmount({
    super.key,
    required this.label,
    required this.amount,
    required this.onEdit,
  });

  final String label;
  final int amount;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.style(14, AppText.w500, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    rupiah(amount),
                    style: AppText.style(
                      34,
                      AppText.w800,
                      color: amount == 0 ? AppColors.faint : AppColors.ink,
                      spacingPercent: -3,
                    ),
                  ),
                ),
              ),
              CircleIconButton(
                icon: LucideIcons.pencil,
                size: 36,
                iconSize: 16,
                onTap: onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pilih tanggal gajian 1–31. `null` = batal.
Future<int?> showPaydaySheet(BuildContext context, int current) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
            const SizedBox(height: 16),
            Text('Tanggal gajian', style: AppText.style(17, AppText.w800)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var d = 1; d <= 31; d++)
                  Material(
                    color: d == current ? AppColors.ink : AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, d),
                      child: Center(
                        child: Text(
                          '$d',
                          style: AppText.style(
                            15,
                            AppText.w700,
                            color: d == current ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tgl 29–31 otomatis jadi hari terakhir di bulan yang lebih pendek.',
              textAlign: TextAlign.center,
              style: AppText.style(12, AppText.w500, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Nilai di kanan baris pengaturan + panah (mis. "Tiap tgl 25 ›").
class ValueChevron extends StatelessWidget {
  const ValueChevron(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: AppText.style(14, AppText.w700, color: AppColors.muted),
        ),
        const SizedBox(width: 6),
        const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.faint),
      ],
    );
  }
}

/// Kerangka layar onboarding langkah 3: top bar, isi, tombol "Lanjut" ke 19.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.children,
    this.canContinue = true,
  });

  final String title;
  final List<Widget> children;
  final bool canContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenX,
                  8,
                  AppSpace.screenX,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTopBar(title: title),
                    const SizedBox(height: 18),
                    ...children,
                    const Spacer(),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Lanjut',
                      onPressed: canContinue
                          ? () => context.push('/pilih-template')
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
