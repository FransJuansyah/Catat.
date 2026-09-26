import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/list_card.dart';
import '../../core/widgets/progress_track.dart';
import '../../data/providers.dart';
import '../../domain/types.dart';
import '../../domain/views.dart';

/// Layar 12 · Detail Kantong.
class PocketDetailScreen extends ConsumerWidget {
  const PocketDetailScreen({super.key, required this.pocketId});

  final String pocketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(pocketDetailProvider(pocketId)).value;
    final today = ref.watch(clockProvider)();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            8,
            AppSpace.screenX,
            24,
          ),
          children: [
            AppTopBar(
              title: detail == null ? '' : 'Kantong ${detail.pocket.name}',
              trailingIcon: LucideIcons.pencil,
              onTrailing: () => context.push('/kantong'),
            ),
            if (detail != null) ...[
              const SizedBox(height: 20),
              _Hero(detail: detail),
              const SizedBox(height: 16),
              _Tip(detail: detail),
              const SizedBox(height: AppSpace.section),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Riwayat ${detail.pocket.name}',
                      style: AppText.style(
                        17,
                        AppText.w800,
                        spacingPercent: -1,
                      ),
                    ),
                  ),
                  Text(
                    monthYear(today),
                    style: AppText.style(
                      12,
                      AppText.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (detail.expenses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Text(
                    'Belum ada pengeluaran di kantong ini.',
                    textAlign: TextAlign.center,
                    style: AppText.style(
                      14,
                      AppText.w500,
                      color: AppColors.muted,
                    ),
                  ),
                )
              else
                ListCard(
                  children: [
                    for (final e in detail.expenses)
                      ExpenseTile(
                        entry: e,
                        useCategoryIcon: true,
                        subtitle: Text(
                          [
                            shortDate(e.occurredAt),
                            if (e.source == ExpenseSource.scan) 'dari scan',
                          ].join(' · '),
                          style: AppText.style(
                            12,
                            AppText.w500,
                            color: AppColors.muted,
                          ),
                        ),
                        onTap: () => context.push('/transaksi/${e.id}'),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.detail});

  final PocketDetail detail;

  @override
  Widget build(BuildContext context) {
    final pocket = detail.pocket;
    final color = Color(pocket.color);
    final b = pocket.balance;
    final light = Colors.white.withValues(alpha: 0.78);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: PocketVisuals.icon(pocket.iconKey),
                background: Colors.white,
                color: color,
                size: 28,
                iconSize: 14,
              ),
              const SizedBox(width: 8),
              Text(
                'Sisa di kantong',
                style: AppText.style(14, AppText.w700, color: light),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(b.remaining),
              style: AppText.style(
                38,
                AppText.w800,
                color: Colors.white,
                spacingPercent: -3,
              ),
            ),
          ),
          Text(
            'Terpakai ${rupiah(b.spent)} dari ${rupiah(b.available)}',
            style: AppText.style(13, AppText.w500, color: light),
          ),
          const SizedBox(height: 16),
          ProgressTrack(
            value: b.usedRatio,
            color: Colors.white,
            track: Colors.white.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }
}

String _paydayPhrase(int days) => switch (days) {
  0 => 'hari ini gajian',
  1 => 'gajian besok',
  _ => 'gajian $days hari lagi',
};

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _Tip extends StatelessWidget {
  const _Tip({required this.detail});

  final PocketDetail detail;

  @override
  Widget build(BuildContext context) {
    final color = Color(detail.pocket.color);
    final b = detail.pocket.balance;
    final days = detail.daysToPayday;
    final String text;
    if (b.remaining < 0) {
      text =
          'Kantong ini udah minus ${rupiahShort(-b.remaining)}. Coba pindahin saldo dari kantong lain ya.';
    } else if (b.isLow(thresholdPercent: detail.lowThresholdPercent)) {
      final pct = b.available == 0
          ? 0
          : (b.remaining * 100 / b.available).round();
      text = days == null
          ? 'Tinggal $pct% lagi di kantong ini. Rem dulu ya!'
          : 'Tinggal $pct% lagi, ${_paydayPhrase(days)}. Rem dulu ya!';
    } else {
      text = days == null
          ? 'Masih sisa ${rupiahShort(b.remaining)} di kantong ini. Aman, pertahankan!'
          : '${_capitalize(_paydayPhrase(days))} & masih sisa ${rupiahShort(b.remaining)}. Aman, pertahankan!';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PocketVisuals.soft(color),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.sparkles, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.style(
                13,
                AppText.w700,
                color: PocketVisuals.deep(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
