import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/providers.dart';
import '../../domain/report.dart';
import 'export_screen.dart';

/// Layar 15 · Loading: Siapin Laporan. Lanjut ke Laporan Siap (16).
class ExportProgressScreen extends ConsumerStatefulWidget {
  const ExportProgressScreen({super.key, required this.request});

  final ExportRequest request;

  @override
  ConsumerState<ExportProgressScreen> createState() =>
      _ExportProgressScreenState();
}

class _ExportProgressScreenState extends ConsumerState<ExportProgressScreen> {
  int _done = 0;
  ReportData? _data;

  String get _formatName =>
      widget.request.format == ExportFormat.pdf ? 'PDF' : 'Excel';

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  /// Tiap langkah minimal sebentar supaya progresnya kebaca mata.
  Future<T> _step<T>(Future<T> work) async {
    final results = await Future.wait([
      work,
      Future<void>.delayed(const Duration(milliseconds: 500)),
    ]);
    if (mounted) setState(() => _done++);
    return results.first as T;
  }

  Future<void> _run() async {
    final repo = ref.read(reportRepositoryProvider);
    final exporter = ref.read(reportExporterProvider);
    final now = ref.read(clockProvider)();
    final req = widget.request;
    try {
      final data = await _step(repo.load(req.range));
      if (mounted) setState(() => _data = data);
      final built = await _step(
        exporter.build(data, req.format, createdAt: now),
      );
      final result = await _step(
        exporter.save(
          built.bytes,
          req.range.fileName(req.format),
          req.format,
          built.detail,
        ),
      );
      if (mounted) context.pushReplacement('/export/siap', extra: result);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan gagal dibuat, coba lagi ya.')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _data?.recordCount;
    final steps = [
      count == null ? 'Kumpulin catatan' : 'Kumpulin $count catatan',
      'Hitung per kantong',
      'Rapiin jadi $_formatName',
    ];
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenX),
            child: Column(
              children: [
                const Spacer(),
                _Preview(
                  title:
                      'LAPORAN ${widget.request.range.shortLabel.toUpperCase()}',
                  data: _data,
                ),
                const SizedBox(height: 36),
                Text(
                  'Laporanmu lagi disiapin…',
                  textAlign: TextAlign.center,
                  style: AppText.style(24, AppText.w800, spacingPercent: -2),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.request.range.shortLabel} · $_formatName',
                  style: AppText.style(
                    14,
                    AppText.w500,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (_done + 0.5) / (steps.length + 0.5)),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 10,
                      color: AppColors.ink,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                for (final (i, label) in steps.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: i < _done
                              ? const IconBadge(
                                  icon: LucideIcons.check,
                                  background: AppColors.ink,
                                  color: AppColors.lime,
                                  size: 28,
                                  iconSize: 16,
                                )
                              : i == _done
                              ? const CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppColors.ink,
                                  backgroundColor: AppColors.line,
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.line,
                                      width: 3,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: AppText.style(
                            16,
                            AppText.w700,
                            color: i <= _done ? AppColors.ink : AppColors.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu kertas laporan dengan grafik batang dari data asli.
class _Preview extends StatelessWidget {
  const _Preview({required this.title, required this.data});

  final String title;
  final ReportData? data;

  static const _fallback = [0.45, 0.7, 0.4, 0.8, 0.6, 0.3, 0.75, 0.55];

  @override
  Widget build(BuildContext context) {
    final bars = _bars();
    return Container(
      width: 240,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: LucideIcons.fileText,
                background: PocketVisuals.soft(AppColors.danger),
                color: AppColors.danger,
                size: 32,
                square: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(11, AppText.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 76,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, (h, color)) in bars.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: h),
                      duration: Duration(milliseconds: 400 + i * 60),
                      builder: (context, v, _) => Container(
                        height: 60 * v,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 8, width: 170, color: AppColors.track),
          const SizedBox(height: 8),
          Container(height: 8, width: 100, color: AppColors.track),
        ],
      ),
    );
  }

  /// Tinggi batang 0..1: pengeluaran per kantong (atau pola bawaan).
  List<(double, Color)> _bars() {
    final pockets = data?.pockets ?? const <PocketReport>[];
    final colors = pockets.isEmpty
        ? const [Color(0xFF6D5DFC), Color(0xFFFF4F7B), Color(0xFF12A36B)]
        : [for (final p in pockets) Color(p.pocket.color)];
    final spent = [for (final p in pockets) p.spent];
    final max = spent.isEmpty ? 0 : spent.reduce(math.max);
    if (max <= 0) {
      return [
        for (final (i, h) in _fallback.indexed) (h, colors[i % colors.length]),
      ];
    }
    return [
      for (final (i, p) in pockets.indexed)
        (math.max(0.12, p.spent / max), colors[i]),
    ];
  }
}
