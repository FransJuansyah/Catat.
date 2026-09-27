import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/export/report_exporter.dart';
import '../../data/providers.dart';
import '../../domain/report.dart';

/// "84 KB" / "2,4 MB".
String fileSizeLabel(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// Layar 16 · Laporan Siap.
class ExportDoneScreen extends ConsumerWidget {
  const ExportDoneScreen({super.key, required this.result});

  final ExportResult result;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(reportExporterProvider).open(result);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada aplikasi buat buka file ini. Coba Bagikan.'),
        ),
      );
    }
  }

  Future<void> _share() => SharePlus.instance.share(
    ShareParams(
      files: [XFile(result.localPath, mimeType: result.mime)],
      subject: result.fileName,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdf = result.format == ExportFormat.pdf;
    final color = pdf ? AppColors.danger : AppColors.success;
    final saved = result.uri != null;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            8,
            AppSpace.screenX,
            8,
          ),
          child: Column(
            children: [
              const Spacer(),
              PopIn(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Appear(
                delay: Appear.step(0),
                child: Text(
                  'Laporan siap!',
                  style: AppText.style(34, AppText.w800, spacingPercent: -3),
                ),
              ),
              const SizedBox(height: 6),
              Appear(
                delay: Appear.step(1),
                child: Text(
                  saved
                      ? 'Udah kesimpen di ${result.location == 'Download' ? 'folder Download' : result.location}'
                      : 'Belum bisa simpan ke Download, bagikan aja ya',
                  textAlign: TextAlign.center,
                  style: AppText.style(
                    14,
                    AppText.w500,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Appear(
                delay: Appear.step(2),
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.cardPad),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.cardLg),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      IconBadge(
                        icon: pdf ? LucideIcons.fileText : LucideIcons.sheet,
                        background: PocketVisuals.soft(color),
                        color: color,
                        size: 48,
                        square: true,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.fileName,
                              style: AppText.style(15, AppText.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${fileSizeLabel(result.sizeBytes)} · ${result.detail}',
                              style: AppText.style(
                                13,
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
              ),
              const Spacer(flex: 2),
              if (saved) ...[
                AppButton(
                  label: 'Buka file',
                  onPressed: () => _open(context, ref),
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                label: 'Bagikan',
                icon: LucideIcons.share,
                style: saved
                    ? AppButtonStyle.secondary
                    : AppButtonStyle.primary,
                onPressed: _share,
              ),
              TextButton(
                onPressed: () => context.go('/laporan'),
                child: Text(
                  'Kembali ke Laporan',
                  style: AppText.style(
                    14,
                    AppText.w700,
                    color: AppColors.muted,
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
