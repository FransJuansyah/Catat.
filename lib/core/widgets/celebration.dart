import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Satu pita di desain: posisi (pecahan lebar/tinggi layar), ukuran, sudut,
/// warna (layar 10, 18, 31).
typedef ConfettiPiece = (
  double x,
  double y,
  double w,
  double h,
  double angle,
  Color color,
);

/// Lama total animasi pita. Sengaja berhenti (hemat baterai, test tidak
/// menunggu selamanya).
const _total = Duration(milliseconds: 4500);

/// Latar pita untuk layar perayaan: pita meledak dari [originKey] (ikon
/// centang / dompet), jatuh sambil berputar lalu memudar; pita desain
/// melayang ke tempatnya & bergoyang pelan. "Kurangi animasi" di HP →
/// pita diam seperti desain.
class ConfettiLayer extends StatefulWidget {
  const ConfettiLayer({
    super.key,
    required this.pieces,
    this.originKey,
    this.burstCount = 36,
  });

  final List<ConfettiPiece> pieces;

  /// Widget asal ledakan. null / belum ter-layout → tengah, 35% dari atas.
  final GlobalKey? originKey;
  final int burstCount;

  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _time = ValueNotifier<double>(0);
  final _layer = GlobalKey();
  Offset? _origin;
  late final List<_Particle> _burst;
  bool _static = false;

  @override
  void initState() {
    super.initState();
    final colors = {...widget.pieces.map((p) => p.$6), Colors.white}.toList();
    final rnd = math.Random(7);
    _burst = [
      for (var i = 0; i < widget.burstCount; i++)
        _Particle.random(rnd, colors[i % colors.length]),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _static = MediaQuery.disableAnimationsOf(context);
    if (_static) {
      _ticker.stop();
      _time.value = _total.inMilliseconds / 1000;
    } else if (!_ticker.isActive && _time.value == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _origin = _findOrigin();
        HapticFeedback.mediumImpact();
        _ticker.start();
      });
    }
  }

  Offset? _findOrigin() {
    final target = widget.originKey?.currentContext?.findRenderObject();
    final layer = _layer.currentContext?.findRenderObject();
    if (target is! RenderBox || layer is! RenderBox || !target.hasSize) {
      return null;
    }
    return layer.globalToLocal(
      target.localToGlobal(target.size.center(Offset.zero)),
    );
  }

  void _tick(Duration elapsed) {
    if (elapsed >= _total) {
      _ticker.stop();
      _time.value = _total.inMilliseconds / 1000;
      return;
    }
    _time.value = elapsed.inMicroseconds / 1e6;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        key: _layer,
        child: CustomPaint(
          painter: _ConfettiPainter(
            time: _time,
            pieces: widget.pieces,
            burst: _static ? const [] : _burst,
            origin: () => _origin,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle.random(math.Random r, this.color)
    : angle = -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.4,
      speed = 520 + r.nextDouble() * 620,
      w = 6 + r.nextDouble() * 7,
      h = 4 + r.nextDouble() * 4,
      spin = (r.nextDouble() - 0.5) * 14,
      flip = 4 + r.nextDouble() * 8,
      life = 1.7 + r.nextDouble() * 0.8,
      delay = r.nextDouble() * 0.12,
      round = r.nextDouble() < 0.25;

  final double angle;
  final double speed;
  final double w;
  final double h;
  final double spin;
  final double flip;
  final double life;
  final double delay;
  final bool round;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.time,
    required this.pieces,
    required this.burst,
    required this.origin,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final List<ConfettiPiece> pieces;
  final List<_Particle> burst;
  final Offset? Function() origin;

  static const _drag = 2.2;
  static const _gravity = 900.0;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final end = _total.inMilliseconds / 1000;
    final from = origin() ?? Offset(size.width / 2, size.height * 0.35);
    final paint = Paint();

    // Ledakan.
    for (final p in burst) {
      final lt = t - p.delay;
      if (lt <= 0 || lt >= p.life) continue;
      final damp = (1 - math.exp(-_drag * lt)) / _drag;
      final pos =
          from +
          Offset(
            math.cos(p.angle) * p.speed * damp,
            math.sin(p.angle) * p.speed * damp + 0.5 * _gravity * lt * lt * 0.6,
          );
      final fade = ((p.life - lt) / 0.5).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(p.spin * lt)
        // Pita "membalik" seperti kertas: lebarnya menyempit-melebar.
        ..scale(math.cos(p.flip * lt).abs().clamp(0.15, 1.0), 1);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.h * 0.6, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }

    // Pita desain: terbang dari asal ke tempatnya, lalu bergoyang pelan.
    for (final (i, (x, y, w, h, angle, color)) in pieces.indexed) {
      final target = Offset(size.width * x + w / 2, size.height * y + h / 2);
      final start = 0.08 + i * 0.05;
      final k = Curves.easeOutBack.transform(
        ((t - start) / 0.75).clamp(0.0, 1.0),
      );
      if (t < start && t < end) continue;
      final settle = ((end - t) / (end - 1.2)).clamp(0.0, 1.0);
      final phase = i * 1.3;
      final bob = math.sin(t * 2.4 + phase) * 5 * settle;
      final wobble = math.sin(t * 1.9 + phase) * 0.25 * settle;
      final pos = Offset.lerp(from, target, k)! + Offset(0, bob * k);
      paint.color = color.withValues(alpha: k.clamp(0.0, 1.0));
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(angle + (1 - k) * math.pi * 2 * (i.isEven ? 1 : -1) + wobble)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
            const Radius.circular(2),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.pieces != pieces || old.burst != burst;
}

/// Masuk dengan memantul (ikon centang / dompet di layar perayaan).
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  static const _length = Duration(milliseconds: 750);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + _length,
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _c,
    curve: Interval(_start, 1, curve: Curves.elasticOut),
  );

  double get _start =>
      widget.delay.inMilliseconds / (widget.delay + _length).inMilliseconds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Muncul pelan dari bawah, berurutan lewat [delay] (judul, nominal, kartu,
/// tombol).
class Appear extends StatefulWidget {
  const Appear({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 18,
  });

  final Widget child;
  final Duration delay;
  final double offsetY;

  /// Jeda antar-elemen yang disarankan.
  static Duration step(int i) => Duration(milliseconds: 120 + i * 90);

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  static const _length = Duration(milliseconds: 480);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + _length,
  );
  late final Animation<double> _v = CurvedAnimation(
    parent: _c,
    curve: Interval(
      widget.delay.inMilliseconds / (widget.delay + _length).inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _v,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _v.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _v.value) * widget.offsetY),
        child: child,
      ),
    ),
  );
}

/// Angka yang naik dari 0 ke [value] (nominal gaji / pemasukan masuk).
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.delay = Duration.zero,
  });

  final int value;
  final String Function(int) format;
  final TextStyle style;
  final Duration delay;

  static const _length = Duration(milliseconds: 1100);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(format(value), style: style);
    }
    final total = delay + _length;
    final curve = Interval(
      delay.inMilliseconds / total.inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, v, _) =>
          Text(format((value * curve.transform(v)).round()), style: style),
    );
  }
}
