import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/pocket_card.dart';
import '../../data/demo_data.dart';

/// Layar 03 · Beranda — design/screens/03 · Beranda.png
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screenX,
          8,
          AppSpace.screenX,
          24,
        ),
        children: [
          const _Header(),
          const SizedBox(height: AppSpace.section),
          const _BalanceHero(),
          const SizedBox(height: AppSpace.section),
          _ScanBanner(onTap: () => context.push('/scan')),
          const SizedBox(height: AppSpace.section),
          Row(
            children: [
              Expanded(
                child: Text(
                  '3 Kantong kamu',
                  style: AppText.style(17, AppText.w800, spacingPercent: -1),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/kantong'),
                child: Text(
                  'Atur',
                  style: AppText.style(
                    13,
                    AppText.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.section),
          for (final (i, pocket) in DemoData.pockets.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            PocketCard(
              pocket: pocket,
              onTap: () => context.push('/kantong/${pocket.id}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

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
          child: Text(
            DemoData.userName[0],
            style: AppText.style(18, AppText.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hai, ${DemoData.userName}',
                style: AppText.style(18, AppText.w800, spacingPercent: -1),
              ),
              const SizedBox(height: 1),
              Text(
                'Gajian besok, tahan dulu ya',
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
  const _BalanceHero();

  @override
  Widget build(BuildContext context) {
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
              rupiah(DemoData.remaining),
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
                  'dari gaji ${rupiah(DemoData.salary)}',
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
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.check,
                      size: 14,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: 4),
                    Text('On track', style: AppText.style(12, AppText.w800)),
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
