import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/app_button.dart';

/// Kartu putih polos pembungkus satu kelompok pengaturan (layar 22).
class WhiteCard extends StatelessWidget {
  const WhiteCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: child,
    );
  }
}

/// Chip pilihan cepat (10% · 20% · Custom, Rp 50rb · Semua).
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.ink,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color color;

  /// Latar putih ber-border saat tidak dipilih (layar 25), bukan abu.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: selected
          ? color
          : outlined
          ? AppColors.card
          : AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: outlined && !selected
            ? const BorderSide(color: AppColors.line)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppText.style(
                  14,
                  AppText.w800,
                  color: selected
                      ? Colors.white
                      : enabled
                      ? AppColors.ink
                      : AppColors.faint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tema slider kantong: garis tebal warna kantong + knob putih bercincin.
SliderThemeData pocketSliderTheme(BuildContext context, Color color) =>
    SliderTheme.of(context).copyWith(
      trackHeight: 8,
      activeTrackColor: color,
      inactiveTrackColor: AppColors.track,
      thumbShape: _RingThumb(color),
      rangeThumbShape: _RingRangeThumb(color),
      overlayColor: color.withValues(alpha: 0.12),
      trackShape: const RoundedRectSliderTrackShape(),
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
      showValueIndicator: ShowValueIndicator.never,
    );

void _paintRing(Canvas canvas, Offset center, Color color) {
  canvas
    ..drawCircle(
      center.translate(0, 1.5),
      13,
      Paint()
        ..color = const Color(0x260E0E10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    )
    ..drawCircle(center, 13, Paint()..color = Colors.white)
    ..drawCircle(
      center,
      11.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
}

class _RingThumb extends SliderComponentShape {
  const _RingThumb(this.color);

  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(13);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) => _paintRing(context.canvas, center, color);
}

class _RingRangeThumb extends RangeSliderThumbShape {
  const _RingRangeThumb(this.color);

  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(13);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    TextDirection? textDirection,
    required SliderThemeData sliderTheme,
    Thumb? thumb,
    bool? isPressed,
  }) => _paintRing(context.canvas, center, color);
}

/// Bottom sheet isi persen 0–100 (chip "Custom" di layar 22).
Future<int?> showPercentSheet(BuildContext context, {int initial = 0}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (context) {
      var value = initial;
      return StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.disabledBg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Persen jatah',
                  style: AppText.style(
                    13,
                    AppText.w500,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$value%',
                  style: AppText.style(
                    40,
                    AppText.w800,
                    color: value == 0 ? AppColors.faint : AppColors.ink,
                    spacingPercent: -3,
                  ),
                ),
                const SizedBox(height: 16),
                AmountKeypad(
                  onKey: (k) => setState(() {
                    if (k == '000') return;
                    final next = k == 'del'
                        ? value ~/ 10
                        : value * 10 + int.parse(k);
                    if (next <= 100) value = next;
                  }),
                  onClear: () => setState(() => value = 0),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Pakai',
                  onPressed: () => Navigator.pop(context, value),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
