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
import '../../domain/templates.dart';
import '../../domain/types.dart';

/// Layar 19 · Pilih Template Kantong (langkah 3 dari 3 onboarding).
class TemplateScreen extends ConsumerStatefulWidget {
  const TemplateScreen({super.key});

  @override
  ConsumerState<TemplateScreen> createState() => _TemplateScreenState();
}

class _TemplateScreenState extends ConsumerState<TemplateScreen> {
  bool _saving = false;

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref.read(onboardingProvider.notifier).finish();
      if (!mounted) return;
      // Penghasilan tidak tetap belum punya pemasukan → langsung ke Beranda.
      final mode = ref.read(onboardingProvider).mode;
      context.go(mode == IncomeMode.irregular ? '/beranda' : '/gajian-masuk');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi ya.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const AppTopBar(title: 'Langkah 4 dari 4'),
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
                    DashedCard(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pilih yang paling mirip dulu, nanti nama & persennya bisa diubah di Atur kantong.',
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const IconBadge(
                            icon: LucideIcons.plus,
                            background: AppColors.lime,
                            color: AppColors.ink,
                            size: 40,
                            iconSize: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bikin sendiri',
                                  style: AppText.style(15, AppText.w800),
                                ),
                                Text(
                                  'Atur nama, ikon & persen sesukamu',
                                  style: AppText.style(
                                    12,
                                    AppText.w500,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Pakai template ini',
                      loading: _saving,
                      onPressed: _finish,
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
