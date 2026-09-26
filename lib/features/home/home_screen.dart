import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/pocket_card.dart';
import '../../data/providers.dart';
import '../../domain/home_summary.dart';

/// Layar 03 · Beranda — design/screens/03 · Beranda.png
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _paydayShown = false;

  @override
  void initState() {
    super.initState();
    // Periode gaji baru → tampilkan "Gajian masuk!" sekali.
    ref.listenManual(paydayProvider, (_, next) {
      final info = next.value;
      if (info == null || info.celebrated || _paydayShown || !mounted) return;
      _paydayShown = true;
      context.push('/gajian-masuk');
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(homeSummaryProvider);
    return SafeArea(
      bottom: false,
      child: switch (summary) {
        AsyncData(:final value) => _HomeContent(summary: value),
        AsyncError() => Center(
          child: Text(
            'Gagal memuat data. Coba buka ulang aplikasi.',
            style: AppText.style(14, AppText.w500, color: AppColors.muted),
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screenX,
        8,
        AppSpace.screenX,
        24,
      ),
      children: [
        _Header(name: summary.userName, daysToPayday: summary.daysToPayday),
        const SizedBox(height: AppSpace.section),
        _BalanceHero(summary: summary),
        const SizedBox(height: AppSpace.section),
        _ScanBanner(onTap: () => context.push('/scan')),
        const SizedBox(height: AppSpace.section),
        Row(
          children: [
            Expanded(
              child: Text(
                '${summary.pockets.length} Kantong kamu',
                style: AppText.style(17, AppText.w800, spacingPercent: -1),
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/kantong'),
              child: Text(
                'Atur',
                style: AppText.style(13, AppText.w700, color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.section),
        for (final (i, pocket) in summary.pockets.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          PocketCard(
            pocket: pocket,
            onTap: () => context.push('/kantong/${pocket.id}'),
          ),
        ],
      ],
    );
  }
}

String paydayHint(int days) => switch (days) {
  0 => 'Hari ini gajian, asik!',
  1 => 'Gajian besok, tahan dulu ya',
  _ => 'Gajian $days hari lagi',
};

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.daysToPayday});

  final String name;
  final int daysToPayday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.lime,
            shape: BoxShape.circle,
          ),
          child: name.isEmpty
              ? const Icon(LucideIcons.user, size: 20, color: AppColors.ink)
              : Text(
                  name[0].toUpperCase(),
                  style: AppText.style(18, AppText.w800),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Hai!' : 'Hai, $name',
                style: AppText.style(18, AppText.w800, spacingPercent: -1),
              ),
              const SizedBox(height: 1),
              Text(
                paydayHint(daysToPayday),
                style: AppText.style(13, AppText.w500, color: AppColors.muted),
              ),
            ],
          ),
        ),
        CircleIconButton(
          icon: LucideIcons.bell,
          size: 44,
          onTap: () => context.push('/gajian-masuk'),
        ),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final onTrack = summary.onTrack;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sisa duitmu bulan ini',
            style: AppText.style(14, AppText.w500, color: AppColors.faint),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(summary.remaining),
              style: AppText.style(
                38,
                AppText.w800,
                color: Colors.white,
                spacingPercent: -3,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'dari gaji ${rupiah(summary.salary)}',
                  style: AppText.style(
                    13,
                    AppText.w500,
                    color: AppColors.faint,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: onTrack ? AppColors.lime : const Color(0xFFFFE8EE),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      onTrack ? LucideIcons.check : LucideIcons.triangleAlert,
                      size: 14,
                      color: onTrack ? AppColors.ink : const Color(0xFFB3264F),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      onTrack ? 'On track' : 'Rem dulu',
                      style: AppText.style(
                        12,
                        AppText.w800,
                        color: onTrack
                            ? AppColors.ink
                            : const Color(0xFFB3264F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanBanner extends StatelessWidget {
  const _ScanBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.lime,
      borderRadius: BorderRadius.circular(AppRadius.cardLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              const IconBadge(
                icon: LucideIcons.scanLine,
                background: AppColors.ink,
                color: AppColors.lime,
                iconSize: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scan struk', style: AppText.style(16, AppText.w800)),
                    const SizedBox(height: 2),
                    Text(
                      'Foto aja, langsung kecatat',
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: AppColors.limeText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: AppColors.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
