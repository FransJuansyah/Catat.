import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import 'icon_badge.dart';

/// Toggle 48×28: ON = track ink + knob lime, OFF = track abu + knob putih.
class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppColors.ink : AppColors.disabledBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? AppColors.lime : Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Radio 22: ON = lingkaran ink + titik lime.
class AppRadio extends StatelessWidget {
  const AppRadio({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : null,
        shape: BoxShape.circle,
        border: selected
            ? null
            : Border.all(color: const Color(0xFFC9C9C2), width: 2),
      ),
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

/// Kartu bergaris putus-putus (Upload slip, Bikin sendiri).
class DashedCard extends StatelessWidget {
  const DashedCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Di atas latar kartu; kalau di bawah, garisnya tertutup Material.
      foregroundPainter: _DashedRRectPainter(),
      child: Material(
        color: const Color(0xFFFBFBF7),
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.cardPad),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Kartu putus-putus dengan tombol + lime (Bikin sendiri, Tambah kantong).
class DashedAddCard extends StatelessWidget {
  const DashedAddCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DashedCard(
      onTap: onTap,
      child: Row(
        children: [
          const IconBadge(
            icon: LucideIcons.plus,
            background: AppColors.lime,
            color: AppColors.ink,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.style(15, AppText.w800)),
                Text(
                  subtitle,
                  style: AppText.style(
                    12,
                    AppText.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBDBDB4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          const Radius.circular(AppRadius.card),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 11) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bar pembagian kantong (persen) — layar 02 & 19.
class SplitBar extends StatelessWidget {
  const SplitBar({
    super.key,
    required this.parts,
    this.height = 12,
    this.gap = 4,
  });

  /// (persen, warna ARGB)
  final List<(int, int)> parts;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    // Bagian bisa berupa persen atau nominal (ribuan) → dinormalkan supaya
    // perbandingannya tetap benar (flex dibatasi, nominal besar ikut rata).
    final total = parts.fold<int>(0, (s, p) => s + (p.$1 > 0 ? p.$1 : 0));
    return Row(
      children: [
        for (final (i, (percent, color)) in parts.indexed) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            flex: total <= 0
                ? 1
                : (percent * 1000 / total).round().clamp(1, 1000),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: Color(color),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Pilihan segmen (mis. Harian / Mingguan / Bulanan) — layar 20, 28.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.segmentBg,
        borderRadius: BorderRadius.circular(AppRadius.segment),
      ),
      child: Row(
        children: [
          for (final (v, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? AppColors.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: AppText.style(
                      13,
                      v == value ? AppText.w800 : AppText.w500,
                      color: v == value ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kartu pilihan besar dengan radio (layar 19, 27).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: selected ? AppColors.ink : AppColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.cardPad),
          child: child,
        ),
      ),
    );
  }
}
