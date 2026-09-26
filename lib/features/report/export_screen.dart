import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../domain/report.dart';

/// Pilihan export yang dikirim ke layar 15.
class ExportRequest {
  const ExportRequest(this.range, this.format);

  final ReportRange range;
  final ExportFormat format;
}

/// Layar 07 · Export Laporan.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.month});

  /// Bulan yang sedang dilihat di layar Laporan (akhir rentang).
  final DateTime month;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  ReportSpan _span = ReportSpan.month;
  ExportFormat _format = ExportFormat.pdf;

  @override
  Widget build(BuildContext context) {
    final options = [
      (ReportSpan.month, 'Bulanan'),
      (ReportSpan.quarter, '3 Bulan'),
      (ReportSpan.year, 'Setahun'),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenX,
                  8,
                  AppSpace.screenX,
                  16,
                ),
                children: [
                  const AppTopBar(title: 'Export Laporan'),
                  const SizedBox(height: 20),
                  Text(
                    'Mau laporan\nyang mana?',
                    style: AppText.style(
                      28,
                      AppText.w800,
                      spacingPercent: -3,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Periode'),
                  for (final (span, title) in options) ...[
                    ChoiceCard(
                      selected: _span == span,
                      onTap: () => setState(() => _span = span),
                      child: Row(
                        children: [
                          AppRadio(selected: _span == span),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppText.style(16, AppText.w800),
                              ),
                              Text(
                                ReportRange.of(span, widget.month).label,
                                style: AppText.style(
                                  13,
                                  AppText.w500,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  _label('Format'),
                  Row(
                    children: [
                      Expanded(
                        child: _FormatCard(
                          selected: _format == ExportFormat.pdf,
                          icon: LucideIcons.fileText,
                          color: AppColors.danger,
                          title: 'PDF',
                          subtitle: 'Rapi buat dibaca',
                          onTap: () =>
                              setState(() => _format = ExportFormat.pdf),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FormatCard(
                          selected: _format == ExportFormat.excel,
                          icon: LucideIcons.sheet,
                          color: AppColors.success,
                          title: 'Excel',
                          subtitle: 'Bisa diolah lagi',
                          onTap: () =>
                              setState(() => _format = ExportFormat.excel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.check,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _format == ExportFormat.pdf
                              ? 'Isinya: ringkasan 3 kantong, catatan harian & foto struk'
                              : 'Isinya: ringkasan, semua pengeluaran & pemasukan per baris',
                          style: AppText.style(
                            13,
                            AppText.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screenX,
                0,
                AppSpace.screenX,
                16,
              ),
              child: AppButton(
                label: 'Download laporan',
                icon: LucideIcons.download,
                onPressed: () => context.push(
                  '/export/proses',
                  extra: ExportRequest(
                    ReportRange.of(_span, widget.month),
                    _format,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: AppText.style(13, AppText.w700, color: AppColors.muted),
    ),
  );
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceCard(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: icon,
            background: PocketVisuals.soft(color),
            color: color,
            size: 44,
            square: true,
          ),
          const SizedBox(height: 12),
          Text(title, style: AppText.style(17, AppText.w800)),
          Text(
            subtitle,
            style: AppText.style(13, AppText.w500, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
