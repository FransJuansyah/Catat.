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
import '../../domain/types.dart';
import '../pocket/low_pocket_sheet.dart';

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
    // Kantong baru saja turun di bawah ambang → peringatan (layar 24), sekali
    // per kejadian. Muncul di atas Beranda setelah layar lain ditutup.
    ref.listenManual(homeSummaryProvider, (prev, next) {
      final before = prev?.value;
      final after = next.value;
      if (before == null || after == null || !mounted) return;
      final known = {for (final p in before.pockets) p.id: p.isLow};
      final newlyLow = after.pockets
          .where((p) => p.isLow && known[p.id] == false)
          .firstOrNull;
      if (newlyLow != null) showLowPocketSheet(context, newlyLow);
    });
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
    final irregular = summary.mode == IncomeMode.irregular;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screenX,
        8,
        AppSpace.screenX,
        24,
      ),
      children: [
        _Header(name: summary.userName, hint: summary.hint),
        const SizedBox(height: AppSpace.section),
        if (irregular)
          _RunningHero(summary: summary)
        else
          _BalanceHero(summary: summary),
        const SizedBox(height: AppSpace.section),
        if (irregular)
          const _QuickActions()
        else
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

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.hint});

  final String name;
  final String hint;

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
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

/// Kartu saldo gaji & uang jajan (layar 03, 33).
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final onTrack = summary.onTrack;
    final allowance = summary.mode == IncomeMode.allowance;
    return _DarkCard(
      children: [
        Text(
          allowance
              ? 'Sisa jajan ${summary.periodNoun}'
              : 'Sisa duitmu ${summary.periodNoun}',
          style: AppText.style(14, AppText.w500, color: AppColors.faint),
        ),
        const SizedBox(height: 4),
        _BigAmount(rupiah(summary.remaining)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                summary.opening != null
                    ? 'dari saldo awal ${rupiah(summary.opening!)}'
                    : allowance
                    ? 'dari ${rupiah(summary.salary)} / ${summary.perNoun}'
                    : 'dari gaji ${rupiah(summary.salary)}',
                style: AppText.style(13, AppText.w500, color: AppColors.faint),
              ),
            ),
            _Pill(
              icon: onTrack ? LucideIcons.check : LucideIcons.triangleAlert,
              label: onTrack ? 'On track' : 'Rem dulu',
              bg: onTrack ? AppColors.lime : const Color(0xFFFFE8EE),
              fg: onTrack ? AppColors.ink : const Color(0xFFB3264F),
            ),
          ],
        ),
        if (summary.dailySafe != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(AppRadius.segment),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  size: 14,
                  color: AppColors.lime,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aman jajan ±${rupiahShort(summary.dailySafe!)}/hari sampai ${summary.dailySafeUntil}',
                    style: AppText.style(12, AppText.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Kartu saldo berjalan penghasilan tidak tetap (layar 32).
class _RunningHero extends StatelessWidget {
  const _RunningHero({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return _DarkCard(
      children: [
        Text(
          'Saldo kamu sekarang',
          style: AppText.style(14, AppText.w500, color: AppColors.faint),
        ),
        const SizedBox(height: 4),
        _BigAmount(rupiah(summary.remaining)),
        const SizedBox(height: 10),
        // Tombol "+ Pemasukan" dibuang: sudah ada kartu "Tambah pemasukan"
        // tepat di bawahnya (keputusan 26 Sep 2026, desain 32/33 disesuaikan).
        Text(
          'Masuk bulan ini',
          style: AppText.style(12, AppText.w500, color: AppColors.faint),
        ),
        Text(
          '+${rupiah(summary.monthIncome)}',
          style: AppText.style(14, AppText.w800, color: AppColors.lime),
        ),
      ],
    );
  }
}

/// Dua tombol cepat: Scan struk & Tambah pemasukan (layar 32).
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required IconData icon,
      required String title,
      required String sub,
      required Color bg,
      required Color badgeBg,
      required Color iconColor,
      required Color titleColor,
      required Color subColor,
      required String route,
    }) {
      return Expanded(
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.cardLg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(route),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.cardPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(
                    icon: icon,
                    background: badgeBg,
                    color: iconColor,
                    size: 40,
                    iconSize: 20,
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: AppText.style(15, AppText.w800, color: titleColor),
                    ),
                  ),
                  Text(
                    sub,
                    style: AppText.style(12, AppText.w500, color: subColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Tinggi kedua tile selalu sama walau teksnya beda panjang.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile(
            icon: LucideIcons.scanLine,
            title: 'Scan struk',
            sub: 'Catat pengeluaran',
            bg: AppColors.lime,
            badgeBg: AppColors.ink,
            iconColor: AppColors.lime,
            titleColor: AppColors.ink,
            subColor: AppColors.limeText,
            route: '/scan',
          ),
          const SizedBox(width: 10),
          tile(
            icon: LucideIcons.circlePlus,
            title: 'Tambah pemasukan',
            sub: 'Baru dapat duit?',
            bg: AppColors.ink,
            badgeBg: AppColors.darkSurface,
            iconColor: AppColors.lime,
            titleColor: Colors.white,
            subColor: AppColors.faint,
            route: '/pemasukan',
          ),
        ],
      ),
    );
  }
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({required this.children});

  final List<Widget> children;

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
        children: children,
      ),
    );
  }
}

class _BigAmount extends StatelessWidget {
  const _BigAmount(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: AppText.style(
          38,
          AppText.w800,
          color: Colors.white,
          spacingPercent: -3,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: AppText.style(12, AppText.w800, color: fg)),
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
