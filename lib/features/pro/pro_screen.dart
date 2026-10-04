import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/providers.dart';
import '../../domain/pro.dart';
import '../scan/scan_widgets.dart';

/// Harga di desain; harga asli dari Google Play kalau sudah tersedia.
const proPriceFallback = 'Rp 49.000';

/// Layar 53 · Buka catat. Pro.
class ProScreen extends ConsumerWidget {
  const ProScreen({super.key});

  static const _features = [
    (
      LucideIcons.scanLine,
      'Scan struk otomatis',
      'Arahin kamera, langsung kecatat',
    ),
    (LucideIcons.download, 'Export PDF & Excel', 'Laporan rapi buat dibagi'),
  ];

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/beranda');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(proStatusProvider).value;
    final pro = ref.watch(proProvider);
    ref.listen(proProvider.select((s) => s.unlockedNow), (_, now) {
      if (!now) return;
      ref.read(proProvider.notifier).seenUnlocked();
      context.push('/pro-kebuka');
    });
    final price = pro.price ?? proPriceFallback;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.ink,
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
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DarkCircleButton(
                        icon: LucideIcons.x,
                        onTap: () => _close(context),
                      ),
                      const SizedBox(height: 20),
                      const _Pill(
                        icon: LucideIcons.sparkles,
                        text: 'PRO',
                        background: AppColors.lime,
                        color: AppColors.ink,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Buka catat. Pro',
                        style: AppText.style(
                          30,
                          AppText.w800,
                          color: Colors.white,
                          spacingPercent: -3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sekali bayar, kepake selamanya. Nggak ada langganan.',
                        style: AppText.style(
                          14,
                          AppText.w500,
                          color: AppColors.faint,
                        ),
                      ),
                      if (status != null && !status.purchased) ...[
                        const SizedBox(height: 14),
                        _Pill(
                          icon: LucideIcons.clock,
                          text: status.inTrial
                              ? 'Trial sisa ${status.daysLeft} hari'
                              : 'Trial kamu udah habis',
                          background: AppColors.darkSurface,
                          color: status.inTrial
                              ? AppColors.lime
                              : AppColors.danger,
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Column(
                          children: [
                            for (final (i, (icon, title, sub))
                                in _features.indexed) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFF3A3A40),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    IconBadge(
                                      icon: icon,
                                      background: AppColors.lime,
                                      color: AppColors.ink,
                                      size: 40,
                                      iconSize: 20,
                                      square: true,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: AppText.style(
                                              15,
                                              AppText.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            sub,
                                            style: AppText.style(
                                              13,
                                              AppText.w500,
                                              color: AppColors.faint,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      LucideIcons.check,
                                      size: 18,
                                      color: AppColors.lime,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              price,
                              style: AppText.style(
                                36,
                                AppText.w800,
                                color: AppColors.lime,
                                spacingPercent: -3,
                              ),
                            ),
                            Text(
                              'sekali bayar · selamanya',
                              style: AppText.style(
                                13,
                                AppText.w500,
                                color: AppColors.faint,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Bayar lewat Google Play: DANA, GoPay, OVO, ShopeePay, pulsa, atau kartu',
                              textAlign: TextAlign.center,
                              style: AppText.style(
                                12,
                                AppText.w500,
                                color: AppColors.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Buka Pro · $price',
                        style: AppButtonStyle.lime,
                        loading: pro.buying,
                        onPressed: pro.pending
                            ? null
                            : ref.read(proProvider.notifier).buy,
                      ),
                      if (pro.pending || pro.message != null) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            pro.pending
                                ? 'Nunggu pembayaran selesai. Pro kebuka otomatis begitu lunas.'
                                : pro.message!,
                            textAlign: TextAlign.center,
                            style: AppText.style(
                              12,
                              AppText.w700,
                              color: pro.pending
                                  ? AppColors.lime
                                  : AppColors.faint,
                            ),
                          ),
                        ),
                      ],
                      Center(
                        child: TextButton(
                          onPressed: ref.read(proProvider.notifier).restore,
                          child: Text(
                            'Pulihkan pembelian',
                            style: AppText.style(
                              13,
                              AppText.w700,
                              color: AppColors.faint,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    required this.background,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: AppText.style(12, AppText.w800, color: color)),
        ],
      ),
    );
  }
}

/// Fitur Pro: kebuka → [child]; trial habis & belum beli → layar 53.
/// Setelah beli, layar ini langsung berganti ke fiturnya.
class ProGate extends ConsumerWidget {
  const ProGate({super.key, required this.feature, required this.child});

  final ProFeature feature;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(proStatusProvider);
    return switch (status) {
      AsyncData(:final value) when value.unlocked => child,
      AsyncData() => const ProScreen(),
      // Gagal baca profil → jangan kunci fitur.
      AsyncError() => child,
      _ => const ColoredBox(color: AppColors.ink),
    };
  }
}
