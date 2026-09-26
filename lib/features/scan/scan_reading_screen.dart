import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/receipt_scanner.dart';
import '../../domain/receipt_parser.dart';
import 'scan_widgets.dart';

const _steps = ['Foto jelas', 'Baca item & harga', 'Tebak kantong'];

/// Layar 09 · Loading: Proses Struk. Baca foto lalu lanjut ke Cek Hasil (05).
class ScanReadingScreen extends ConsumerStatefulWidget {
  const ScanReadingScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<ScanReadingScreen> createState() => _ScanReadingScreenState();
}

class _ScanReadingScreenState extends ConsumerState<ScanReadingScreen> {
  /// Jumlah langkah yang sudah selesai (0–3).
  int _done = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  /// Tiap langkah minimal sebentar supaya progresnya kebaca mata.
  Future<T> _step<T>(Future<T> work) async {
    final results = await Future.wait([
      work,
      Future<void>.delayed(const Duration(milliseconds: 650)),
    ]);
    if (mounted) setState(() => _done++);
    return results.first as T;
  }

  Future<void> _run() async {
    final scanner = ref.read(receiptScannerProvider);
    await _step(Future<void>.value());
    ReceiptData data;
    try {
      data = await _step(scanner.read(widget.imagePath));
    } on Object {
      // OCR gagal (foto rusak dll.) → tetap ke layar 05, isi manual.
      data = const ReceiptData();
      if (mounted) setState(() => _done++);
    }
    await _step(Future.value(guessPocketType(data)));
    if (!mounted) return;
    context.pushReplacement(
      '/hasil-scan',
      extra: ScanResult(imagePath: widget.imagePath, data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.ink,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenX),
              child: Column(
                children: [
                  const Spacer(),
                  _photo(),
                  const SizedBox(height: 32),
                  Text(
                    'Lagi baca strukmu…',
                    style: AppText.style(
                      26,
                      AppText.w800,
                      color: Colors.white,
                      spacingPercent: -2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ngitung total & nebak kantongnya',
                    style: AppText.style(
                      14,
                      AppText.w500,
                      color: AppColors.faint,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: (_done + 0.5) / (_steps.length + 0.5)),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 10,
                        color: AppColors.lime,
                        backgroundColor: AppColors.darkSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final (i, label) in _steps.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _StepRow(
                        label: label,
                        done: i < _done,
                        active: i == _done,
                      ),
                    ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photo() {
    return Container(
      height: 260,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
              cacheWidth: 720,
              errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white),
            ),
            const ScanFrame(),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: done
              ? Container(
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 16,
                    color: AppColors.ink,
                  ),
                )
              : active
              ? const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.lime,
                  backgroundColor: AppColors.darkSurface,
                )
              : Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.darkSurface, width: 3),
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: AppText.style(
            16,
            AppText.w700,
            color: done || active ? Colors.white : AppColors.faint,
          ),
        ),
      ],
    );
  }
}
