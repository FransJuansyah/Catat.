import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/month_picker.dart';
import '../../core/widgets/progress_track.dart';
import '../../data/providers.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/report.dart';

/// Layar 14 · Laporan (tab).
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
    return [
      _SummaryHero(
        data: data,
        title: isThisMonth
            ? 'Total keluar bulan ini'
            : 'Total keluar ${monthYearLong(_month)}',
      ),
      const SizedBox(height: AppSpace.section),
      Text(
        'Per kantong',
        style: AppText.style(17, AppText.w800, spacingPercent: -1),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.cardLg),
        ),
        child: Column(
          children: [for (final p in data.pockets) _PocketRow(report: p)],
        ),
      ),
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

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.data, required this.title});

  final ReportData data;
  final String title;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppText.style(12, AppText.w500, color: AppColors.faint),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppText.style(17, AppText.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(data.totalSpent),
              style: AppText.style(
                36,
                AppText.w800,
                color: Colors.white,
                spacingPercent: -3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              tile(
                data.incomeLabel,
                rupiahShort(data.totalIncome),
                Colors.white,
              ),
              const SizedBox(width: 10),
              tile(
                'Sisa',
                rupiahShort(data.remaining),
                data.remaining < 0 ? const Color(0xFFFF8A80) : AppColors.lime,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PocketRow extends StatelessWidget {
  const _PocketRow({required this.report});

  final PocketReport report;

  @override
  Widget build(BuildContext context) {
    final color = Color(report.pocket.color);
    final budget = report.budget;
    final ratio = budget <= 0
        ? (report.spent > 0 ? 1.0 : 0.0)
        : (report.spent / budget).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                PocketVisuals.icon(report.pocket.iconKey),
                size: 18,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  report.pocket.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(15, AppText.w800),
                ),
              ),
              Text(
                '${rupiahShort(report.spent)} / ${rupiahShort(budget).replaceFirst('Rp ', '')}',
                style: AppText.style(
                  13,
                  AppText.w500,
                  color: report.spent > budget && budget > 0
                      ? AppColors.danger
                      : AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProgressTrack(value: ratio, color: color),
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
