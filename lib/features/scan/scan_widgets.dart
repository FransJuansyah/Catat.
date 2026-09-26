import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';

/// Tombol bulat gelap di atas latar hitam (tutup, flash).
class DarkCircleButton extends StatelessWidget {
  const DarkCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.lime : AppColors.darkSurface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: AppSize.topBarButton,
          height: AppSize.topBarButton,
          child: Icon(
            icon,
            size: 20,
            color: active ? AppColors.ink : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Pil petunjuk ("Pas-in struk di dalam kotak").
class HintPill extends StatelessWidget {
  const HintPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.sparkles, size: 14, color: AppColors.lime),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppText.style(13, AppText.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Galeri / Manual di kiri-kanan tombol jepret.
class SideAction extends StatelessWidget {
  const SideAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Material(
            color: AppColors.darkSurface,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(icon, size: 20, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppText.style(12, AppText.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Tombol jepret: cincin putih + lingkaran lime.
class ShutterButton extends StatelessWidget {
  const ShutterButton({super.key, required this.onTap, this.busy = false});

  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Foto struk',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap == null && !busy
                  ? AppColors.lime.withValues(alpha: 0.4)
                  : AppColors.lime,
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.ink,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Sudut-sudut lime + garis scan yang naik-turun.
class ScanFrame extends StatefulWidget {
  const ScanFrame({super.key, this.animate = true});

  final bool animate;

  @override
  State<ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _line.repeat(reverse: true);
  }

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _line,
      builder: (context, _) => CustomPaint(
        painter: _FramePainter(widget.animate ? _line.value : null),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.progress);

  /// Posisi garis scan 0..1 (null = tanpa garis).
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 36.0;
    const r = 18.0;
    final paint = Paint()
      ..color = AppColors.lime
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    Path corner(Offset o, double dx, double dy) => Path()
      ..moveTo(o.dx, o.dy + dy * (len + r))
      ..lineTo(o.dx, o.dy + dy * r)
      ..arcToPoint(
        Offset(o.dx + dx * r, o.dy),
        radius: const Radius.circular(r),
        clockwise: dx * dy > 0,
      )
      ..lineTo(o.dx + dx * (len + r), o.dy);
    canvas
      ..drawPath(corner(Offset.zero, 1, 1), paint)
      ..drawPath(corner(Offset(w, 0), -1, 1), paint)
      ..drawPath(corner(Offset(0, h), 1, -1), paint)
      ..drawPath(corner(Offset(w, h), -1, -1), paint);

    final t = progress;
    if (t != null) {
      final y = h * (0.12 + 0.76 * t);
      canvas
        ..drawLine(
          Offset(8, y),
          Offset(w - 8, y),
          Paint()
            ..color = AppColors.lime.withValues(alpha: 0.35)
            ..strokeWidth = 14
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        )
        ..drawLine(
          Offset(8, y),
          Offset(w - 8, y),
          Paint()
            ..color = AppColors.lime
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.progress != progress;
}
