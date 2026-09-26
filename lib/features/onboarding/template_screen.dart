import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/controls.dart';
import '../../data/providers.dart';
import '../../domain/templates.dart';

/// Layar 19 · Pilih Template Kantong (langkah 4 dari 5 onboarding). Lanjut
/// ke 42 (saldo awal), atau 43 untuk bikin kantong sendiri.
class TemplateScreen extends ConsumerWidget {
  const TemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
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
                    const AppTopBar(title: 'Langkah 4 dari 5'),
                    const SizedBox(height: 14),
                    Text(
                      'Mau bagi duit\ngaya apa?',
                      style: AppText.style(
                        26,
                        AppText.w800,
                        spacingPercent: -3,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nama & persennya bisa diganti kapan aja',
                      style: AppText.style(
                        14,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final t in PocketTemplates.forMode(draft.mode)) ...[
                      _TemplateCard(
                        template: t,
                        selected: t == draft.template,
                        popular: t == PocketTemplates.forMode(draft.mode).first,
                        onTap: () => ref
                            .read(onboardingProvider.notifier)
                            .setTemplate(t),
                      ),
                      const SizedBox(height: 14),
                    ],
                    DashedAddCard(
                      title: 'Bikin sendiri',
                      subtitle: '2 sampai 6 kantong, atur sesukamu',
                      onTap: () => context.push('/bikin-kantong'),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Pakai template ini',
                      onPressed: () => context.push('/uang-sekarang'),
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

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.popular,
    required this.onTap,
  });

  final PocketTemplate template;
  final bool selected;
  final bool popular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: selected ? AppColors.ink : AppColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(template.name, style: AppText.style(16, AppText.w800)),
                  if (popular) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'Populer',
                        style: AppText.style(11, AppText.w800),
                      ),
                    ),
                  ],
                  const Spacer(),
                  AppRadio(selected: selected),
                ],
              ),
              const SizedBox(height: 10),
              SplitBar(
                parts: [for (final p in template.pockets) (p.percent, p.color)],
                height: 10,
                gap: 3,
              ),
              const SizedBox(height: 10),
              Text(
                template.pockets
                    .map((p) => '${p.name} ${p.percent}%')
                    .join('  ·  '),
                style: AppText.style(12, AppText.w500, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
