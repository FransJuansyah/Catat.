import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';

/// 6 titik PIN (layar 57 & 58). [error] = goyang sebentar saat salah.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.length = 6,
    this.color = AppColors.ink,
    this.empty = AppColors.disabledBg,
    this.error = false,
  });

  final int filled;
  final int length;
  final Color color;
  final Color empty;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(error),
      tween: Tween(begin: error ? 1 : 0, end: 0),
      duration: const Duration(milliseconds: 420),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(12 * v * (v * 20).floor().isEven.sign(), 0),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: error
                    ? AppColors.danger
                    : i < filled
                    ? color
                    : empty,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension on bool {
  int sign() => this ? 1 : -1;
}

/// Keypad angka PIN: tanpa 000, kiri bawah opsional (sidik jari).
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onLeft,
    this.leftIcon,
    this.keyColor = AppColors.card,
    this.textColor = AppColors.ink,
    this.leftColor = AppColors.lime,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onLeft;
  final IconData? leftIcon;
  final Color keyColor;
  final Color textColor;
  final Color leftColor;
  final bool enabled;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['left', '0', 'del'],
  ];

  @override
  Widget build(BuildContext context) {
    Widget key(String k) {
      if (k == 'left') {
        if (leftIcon == null) return const SizedBox(height: 54);
        return SizedBox(
          height: 54,
          child: IconButton(
            onPressed: enabled ? onLeft : null,
            icon: Icon(leftIcon, size: 30, color: leftColor),
          ),
        );
      }
      return Material(
        color: keyColor,
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: !enabled
              ? null
              : k == 'del'
              ? onDelete
              : () => onDigit(k),
          child: SizedBox(
            height: 54,
            child: Center(
              child: k == 'del'
                  ? Icon(LucideIcons.delete, size: 22, color: textColor)
                  : Text(
                      k,
                      style: AppText.style(22, AppText.w700, color: textColor),
                    ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final (r, row) in _rows.indexed) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (final (c, k) in row.indexed) ...[
                if (c > 0) const SizedBox(width: 8),
                Expanded(child: key(k)),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
