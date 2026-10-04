import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/month_picker.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/progress_track.dart';
import '../../core/widgets/usage_charts.dart';
import '../../data/providers.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/report.dart';
import '../../domain/usage_charts.dart';

/// Layar 64 · Laporan (tab): grafik ala pemakaian baterai & data.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    _month = DateTime(now.year, now.month);
  }

  Future<void> _pickMonth(List<DateTime> months) async {
    final picked = await showMonthSheet(
      context,
      months: months,
      selected: _month,
    );
    if (picked != null && mounted) setState(() => _month = picked);
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(monthReportProvider(_month)).value;
    final now = ref.watch(clockProvider)();
    final isThisMonth = _month.year == now.year && _month.month == now.month;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Laporan',
                  style: AppText.style(26, AppText.w800, spacingPercent: -3),
                ),
              ),
              MonthPill(
                label: monthYear(_month),
                onTap: () => _pickMonth(report?.months ?? [_month]),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.section),
          if (report != null) ..._body(report, isThisMonth),
        ],
      ),
    );
  }

  List<Widget> _body(MonthReport report, bool isThisMonth) {
    final data = report.data;
    final today = ref.watch(clockProvider)();
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final lastDay = isThisMonth ? today.day : days;
    final remaining = ref.watch(homeSummaryProvider).value?.remaining;

    // Level saldo (ala grafik level baterai).
    final levels = balanceLevels(
      month: _month,
      expenses: data.expenses,
      incomes: data.incomes,
      today: today,
      endBalance: isThisMonth ? remaining : null,
    );
    final incomeIdx = {for (final d in levels.incomeDays) d - 1};

    // Keluar per hari (ala pemakaian data). Batang yang jauh lebih tinggi
    // dari lainnya dipotong supaya batang lain tetap kelihatan.
    final daily = dailyTotals(data.expenses, _month, days);
    final sorted = [...daily.where((v) => v > 0)]..sort();
    final peak = sorted.isEmpty ? 0 : sorted.last;
    final second = sorted.length < 2 ? peak : sorted[sorted.length - 2];
    final capped = second > 0 && peak > second * 2.5;
    final cap = niceCeil(capped ? second : peak);
    final spentSum = daily.fold(0, (s, v) => s + v);

    final monthShort = monthYear(_month).split(' ').first;
    final xLabels = <int, String>{
      for (final i in [0, 7, 14, 21, days - 1]) i: '${i + 1} $monthShort',
    };
    if (isThisMonth) {
      xLabels.removeWhere((i, _) => (i - (today.day - 1)).abs() < 4);
      xLabels[today.day - 1] = 'Hari ini';
    }

    final autoIncome = data.incomes
        .where((i) => i.auto)
        .fold(0, (s, i) => s + i.amount);
    final otherIncome = data.totalIncome - autoIncome;
    final top = topSpending(data.expenses);

    return [
      _UsageHero(
        data: data,
        title: isThisMonth
            ? 'Kepake bulan ini'
            : 'Kepake ${monthYearLong(_month)}',
      ),
      const SizedBox(height: AppSpace.section),
      _ChartCard(
        title: 'Level saldo',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.zap, size: 11, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              'uang masuk',
              style: AppText.style(12, AppText.w700, color: AppColors.muted),
            ),
          ],
        ),
        children: [
          DailyBarChart(
            values: levels.levels,
            colors: [
              for (var i = 0; i < days; i++)
                incomeIdx.contains(i)
                    ? AppColors.success
                    : (isThisMonth && i == lastDay - 1)
                    ? AppColors.ink
                    : const Color(0xFFC9C9C2),
            ],
            highlights: incomeIdx,
            markers: incomeIdx,
            scaleLabels: const ['100%', '50%', '0%'],
            xLabels: xLabels,
          ),
          if (data.totalIncome > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (autoIncome > 0)
                  Expanded(
                    child: _MiniStat(
                      label: data.incomeLabel,
                      value: '+${rupiahShort(autoIncome)}',
                    ),
                  ),
                if (otherIncome > 0)
                  Expanded(
                    child: _MiniStat(
                      label: autoIncome > 0 ? 'Uang masuk lain' : 'Uang masuk',
                      value: '+${rupiahShort(otherIncome)}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      const SizedBox(height: AppSpace.sectionTight),
      _ChartCard(
        title: 'Keluar per hari',
        trailing: spentSum > 0
            ? Text(
                'Rata-rata ${rupiahShort((spentSum / lastDay).round())}',
                style: AppText.style(12, AppText.w700, color: AppColors.muted),
              )
            : null,
        children: [
          DailyBarChart(
            values: [
              for (var i = 0; i < days; i++)
                i < lastDay ? (daily[i] / cap).clamp(0.0, 1.0) : null,
            ],
            colors: List.filled(days, AppColors.ink),
            scaleLabels: [axisLabel(cap), axisLabel(cap ~/ 2), '0'],
            xLabels: xLabels,
            pill: capped ? (daily.indexOf(peak), axisLabel(peak)) : null,
          ),
        ],
      ),
      if (top.isNotEmpty) ...[
        const SizedBox(height: AppSpace.section),
        Text(
          'Paling banyak makan duit',
          style: AppText.style(17, AppText.w800, spacingPercent: -1),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.cardLg),
          ),
          child: Column(
            children: [
              for (final (i, g) in top.indexed) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.line),
                _TopRow(
                  group: g,
                  ratio: g.total / top.first.total,
                  share: spentSum <= 0 ? 0 : (g.total * 100 / spentSum).round(),
                ),
              ],
            ],
          ),
        ),
      ],
      if (report.insight case final insight?) ...[
        const SizedBox(height: 14),
        _InsightCard(insight: insight),
      ],
      if (data.expenses.isEmpty) ...[
        const SizedBox(height: 14),
        Text(
          'Belum ada pengeluaran di ${monthYearLong(_month)}.',
          textAlign: TextAlign.center,
          style: AppText.style(13, AppText.w500, color: AppColors.muted),
        ),
      ],
      const SizedBox(height: 16),
      SizedBox(
        height: AppSize.buttonHeight,
        child: Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
            side: const BorderSide(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(
              '/export?bulan=${_month.year}-${_month.month.toString().padLeft(2, '0')}',
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.download,
                  size: 20,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 10),
                Text('Export laporan', style: AppText.style(16, AppText.w800)),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

/// Kartu "Kepake bulan ini" + bar pemakaian per kantong (ala kuota data).
class _UsageHero extends StatelessWidget {
  const _UsageHero({required this.data, required this.title});

  final ReportData data;
  final String title;

  static const _rest = 0xFF3A3A40;

  @override
  Widget build(BuildContext context) {
    final used = [
      for (final p in data.pockets)
        if (p.spent > 0) p,
    ]..sort((a, b) => b.spent.compareTo(a.spent));
    final rest = data.remaining > 0 ? data.remaining : 0;
    final parts = [
      for (final p in used) (p.spent, p.pocket.color),
      if (rest > 0) (rest, _rest),
    ];
    Widget legend(Color dot, String name, String value, {bool lime = false}) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(
                    13,
                    AppText.w700,
                    color: lime ? AppColors.lime : Colors.white,
                  ),
                ),
              ),
              Text(
                value,
                style: AppText.style(
                  13,
                  AppText.w700,
                  color: lime ? AppColors.lime : AppColors.faint,
                ),
              ),
            ],
          ),
        );

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
            title,
            style: AppText.style(14, AppText.w500, color: AppColors.faint),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  rupiah(data.totalSpent),
                  style: AppText.style(
                    34,
                    AppText.w800,
                    color: Colors.white,
                    spacingPercent: -3,
                  ),
                ),
                if (data.totalIncome > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    'dari ${rupiahShort(data.totalIncome).replaceFirst('Rp ', '')}',
                    style: AppText.style(
                      14,
                      AppText.w500,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 14),
            SplitBar(parts: parts, height: 14, gap: 3),
          ],
          const SizedBox(height: 6),
          for (final p in used)
            legend(Color(p.pocket.color), p.pocket.name, rupiahShort(p.spent)),
          if (data.totalIncome > 0)
            legend(
              const Color(0xFF55555C),
              'Sisa',
              rupiahShort(data.remaining),
              lime: data.remaining >= 0,
            ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
                child: Text(title, style: AppText.style(15, AppText.w800)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.style(12, AppText.w500, color: AppColors.muted),
        ),
        Text(
          value,
          style: AppText.style(15, AppText.w800, color: AppColors.success),
        ),
      ],
    );
  }
}

/// Satu baris "Paling banyak makan duit" (ala daftar aplikasi boros kuota).
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.group,
    required this.ratio,
    required this.share,
  });

  final SpendGroup group;
  final double ratio;
  final int share;

  @override
  Widget build(BuildContext context) {
    final color = Color(group.pocket.color);
    final small = AppText.style(12, AppText.w500, color: AppColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          IconBadge(
            icon: PocketVisuals.icon(group.iconKey),
            background: PocketVisuals.soft(color),
            color: color,
            size: 40,
            iconSize: 19,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.style(15, AppText.w800),
                      ),
                    ),
                    Text(
                      rupiah(group.total),
                      style: AppText.style(14, AppText.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressTrack(value: ratio, color: color, height: 6),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('${group.count}x catat', style: small),
                    ),
                    Text('$share% dari keluar', style: small),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final ReportInsight insight;

  @override
  Widget build(BuildContext context) {
    final color = Color(insight.pocket?.color ?? 0xFF6D5DFC);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              insight.text,
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
