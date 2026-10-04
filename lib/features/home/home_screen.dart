import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/pocket_card.dart';
import '../../core/widgets/usage_charts.dart';
import '../../data/providers.dart';
import '../../domain/home_summary.dart';
import '../../domain/types.dart';
import '../pocket/low_pocket_sheet.dart';

/// Layar 59 · Beranda — design/screens/59 · Beranda (Ketik & Baterai Duit).png
/// (penghasilan tidak tetap: kartu saldo layar 32).
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
        _TypeBar(onTap: () => context.push('/catat-ketik')),
        const SizedBox(height: AppSpace.section),
        const _WeekCard(),
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

/// Kartu saldo gaji & uang jajan dengan baterai duit (layar 59, 33).
class _BalanceHero extends ConsumerWidget {
  const _BalanceHero({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onTrack = summary.onTrack;
    final allowance = summary.mode == IncomeMode.allowance;
    final week = ref.watch(weekUsageProvider).value;
    final percent = (summary.level * 100).round();
    final days = summary.daysToPayday;
    String? until;
    if (week != null && days > 0) {
      final today = ref.watch(clockProvider)();
      final date = shortDate(
        DateTime(today.year, today.month, today.day + days),
      );
      final noun = allowance ? 'uang jajan masuk' : 'gajian';
      final enough = week.total / 7 * days <= summary.remaining;
      until = enough
          ? 'Cukup sampai $noun $date'
          : 'Bisa kurang sebelum $noun $date';
    }
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
        _Battery(level: summary.level),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$percent%  ',
                          style: AppText.style(
                            15,
                            AppText.w800,
                            color: AppColors.lime,
                          ),
                        ),
                        TextSpan(
                          text: 'dari ${rupiahShort(summary.available)} masuk',
                        ),
                      ],
                    ),
                    style: AppText.style(
                      13,
                      AppText.w500,
                      color: AppColors.faint,
                    ),
                  ),
                  if (until != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      until,
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: AppColors.faint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
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

/// Baterai duit: isi lime = sisa ÷ jatah periode (layar 59).
class _Battery extends StatelessWidget {
  const _Battery({required this.level});

  final double level;

  static const _shell = Color(0xFF3A3A40);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 34,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _shell, width: 2),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: level <= 0 ? 0 : level.clamp(0.04, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: level < 0.2
                        ? const Color(0xFFFF8A80)
                        : AppColors.lime,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 3),
        Container(
          width: 4,
          height: 12,
          decoration: BoxDecoration(
            color: _shell,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

/// Kotak "Catat apa hari ini?" → layar 60 (aksi utama).
class _TypeBar extends StatelessWidget {
  const _TypeBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
        boxShadow: AppShadow.card,
      ),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.cardLg),
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                const IconBadge(
                  icon: LucideIcons.sparkles,
                  background: AppColors.lime,
                  color: AppColors.ink,
                  size: 40,
                  iconSize: 19,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catat apa hari ini?',
                        style: AppText.style(15, AppText.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ketik aja, misal: kopi susu 25rb',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.style(
                          13,
                          AppText.w500,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const IconBadge(
                  icon: LucideIcons.arrowUp,
                  background: AppColors.ink,
                  color: AppColors.lime,
                  size: 40,
                  iconSize: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _dayShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// Pemakaian 7 hari ala "Daily Usage" baterai (layar 59).
class _WeekCard extends ConsumerStatefulWidget {
  const _WeekCard();

  @override
  ConsumerState<_WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends ConsumerState<_WeekCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(weekUsageProvider).value;
    if (week == null) return const SizedBox.shrink();
    final selected = _selected ?? week.peakIndex;
    final day = week.days[selected];
    return Container(
      padding: const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pemakaian 7 hari',
                  style: AppText.style(15, AppText.w800),
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/laporan'),
                child: Text(
                  'Lihat laporan',
                  style: AppText.style(
                    12,
                    AppText.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(week.insight(dayName), style: AppText.style(14, AppText.w700)),
          const SizedBox(height: 12),
          WeekBarChart(
            values: week.totals,
            labels: [
              for (final (i, d) in week.days.indexed)
                i == week.days.length - 1
                    ? 'Hari ini'
                    : _dayShort[d.weekday - 1],
            ],
            selected: selected,
            valueLabel: rupiahShort(week.totals[selected]),
            dateLabel: '${_dayShort[day.weekday - 1]}, ${shortDate(day)}',
            onSelect: (i) => setState(() => _selected = i),
          ),
        ],
      ),
    );
  }
}
