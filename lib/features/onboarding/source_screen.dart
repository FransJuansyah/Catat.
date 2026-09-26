import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/providers.dart';
import '../../domain/types.dart';

/// Layar 27 · Pilih Sumber Uang (langkah 2 dari 5).
class SourceScreen extends ConsumerWidget {
  const SourceScreen({super.key});

  static const _options = [
    (
      IncomeMode.salary,
      LucideIcons.briefcase,
      'Gaji bulanan',
      'Kerja kantoran, gajian tiap bulan',
      Color(0xFF6D5DFC),
    ),
    (
      IncomeMode.allowance,
      LucideIcons.graduationCap,
      'Uang jajan',
      'Pelajar & mahasiswa, harian / mingguan / bulanan',
      Color(0xFFFF8A00),
    ),
    (
      IncomeMode.irregular,
      LucideIcons.bike,
      'Penghasilan tidak tetap',
      'Freelance, ojol, kerja harian. Tambah sendiri tiap dapat duit',
      Color(0xFF12A36B),
    ),
  ];

  static String routeFor(IncomeMode mode) => switch (mode) {
    IncomeMode.salary => '/atur-gaji',
    IncomeMode.allowance => '/atur-jajan',
    IncomeMode.irregular => '/atur-penghasilan',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(onboardingProvider.select((d) => d.mode));
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
                    const AppTopBar(title: 'Langkah 2 dari 5'),
                    const SizedBox(height: 14),
                    Text(
                      'Uangmu biasanya\ndatang dari mana?',
                      style: AppText.style(
                        26,
                        AppText.w800,
                        spacingPercent: -3,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Biar catat. nyesuain cara bagi duitmu. Bisa diganti kapan aja.',
                      style: AppText.style(
                        14,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final (m, icon, title, sub, color) in _options) ...[
                      ChoiceCard(
                        selected: m == mode,
                        onTap: () =>
                            ref.read(onboardingProvider.notifier).setMode(m),
                        child: Row(
                          children: [
                            IconBadge(
                              icon: icon,
                              background: PocketVisuals.soft(color),
                              color: color,
                              size: 48,
                              iconSize: 22,
                              square: true,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AppText.style(16, AppText.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    sub,
                                    style: AppText.style(
                                      12,
                                      AppText.w500,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            AppRadio(selected: m == mode),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEBFF),
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.info,
                            size: 18,
                            color: Color(0xFF3D2FB8),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Apapun pilihannya, tiap duit masuk tetap otomatis kebagi ke 3 kantong.',
                              style: AppText.style(
                                13,
                                AppText.w700,
                                color: const Color(0xFF3D2FB8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Lanjut',
                      onPressed: () => context.push(routeFor(mode)),
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
