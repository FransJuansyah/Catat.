import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';

/// Grafik ala pemakaian baterai & data (layar 59, 64).

const _gridColor = AppColors.line;
const _rightAxis = 40.0;

/// Batas atas skala yang enak dibaca: 480rb → 500rb, 1,3jt → 1,5jt.
int niceCeil(int value) {
  if (value <= 0) return 1;
  final exp = math.pow(10, (math.log(value) / math.ln10).floor()).toInt();
  for (final step in const [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) {
    final v = (step * exp).round();
    if (v >= value) return v;
  }
  return 10 * exp;
}

/// "500rb" / "1,5jt" / "0" untuk label skala.
String axisLabel(int value) {
  if (value >= 1000000) {
    final jt = value / 1000000;
    return '${jt == jt.roundToDouble() ? jt.toStringAsFixed(0) : jt.toStringAsFixed(1).replaceAll('.', ',')}jt';
  }
  if (value >= 1000) return '${(value / 1000).round()}rb';
  return '$value';
}

TextPainter _text(String s, TextStyle style) => TextPainter(
  text: TextSpan(text: s, style: style),
  textDirection: TextDirection.ltr,
)..layout();

void _dashed(Canvas canvas, double y, double width, {bool solid = false}) {
  final paint = Paint()
    ..color = _gridColor
    ..strokeWidth = 1;
  if (solid) {
    canvas.drawLine(Offset(0, y), Offset(width, y), paint);
    return;
  }
  for (var x = 0.0; x < width; x += 7) {
    canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, width), y), paint);
  }
}

/// 7 batang per hari ala "Daily Usage" baterai: hari terpilih ink + angka
/// besar & tanggal di atasnya, hari ini lime. Ketuk batang buat pilih hari.
class WeekBarChart extends StatelessWidget {
  const WeekBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.valueLabel,
    required this.dateLabel,
    required this.onSelect,
  });

  final List<int> values;

  /// Label bawah tiap batang ("Sen", …, "Hari ini").
  final List<String> labels;
  final int selected;
  final String valueLabel;
  final String dateLabel;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final slot = (c.maxWidth - _rightAxis) / values.length;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => onSelect(
            (d.localPosition.dx / slot).floor().clamp(0, values.length - 1),
          ),
          child: CustomPaint(
            size: Size(c.maxWidth, 196),
            painter: _WeekPainter(this),
          ),
        );
      },
    );
  }
}

class _WeekPainter extends CustomPainter {
  _WeekPainter(this.chart);

  final WeekBarChart chart;

  static const top = 56.0, base = 176.0;

  @override
  void paint(Canvas canvas, Size size) {
    final values = chart.values;
    final maxV = niceCeil(values.fold(0, math.max));
    final area = size.width - _rightAxis;
    final slot = area / values.length;
    final bw = math.min(26.0, slot * 0.65);
    final mid = (top + base) / 2;
    _dashed(canvas, top, area);
    _dashed(canvas, mid, area);
    _dashed(canvas, base, area, solid: true);
    final axis = AppText.style(11, AppText.w500, color: AppColors.faint);
    for (final (y, v) in [(top, maxV), (mid, maxV ~/ 2), (base, 0)]) {
      final t = _text(axisLabel(v), axis);
      t.paint(canvas, Offset(area + 6, y - t.height / 2));
    }

    final last = values.length - 1;
    for (var i = 0; i < values.length; i++) {
      final cx = i * slot + slot / 2;
      final h = values[i] / maxV * (base - top);
      final color = i == chart.selected
          ? AppColors.ink
          : i == last
          ? AppColors.lime
          : AppColors.disabledBg;
      final rect = h <= 0
          ? Rect.fromLTWH(cx - bw / 2, base - 3, bw, 3)
          : Rect.fromLTWH(
              cx - bw / 2,
              base - math.max(h, 6),
              bw,
              math.max(h, 6),
            );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = h <= 0 && i != chart.selected ? AppColors.track : color,
      );
      final selected = i == chart.selected || i == last;
      final label = _text(
        chart.labels[i],
        AppText.style(
          11,
          selected ? AppText.w800 : AppText.w500,
          color: selected ? AppColors.ink : AppColors.faint,
        ),
      );
      label.paint(canvas, Offset(cx - label.width / 2, base + 4));
    }

    // Garis & angka hari terpilih.
    final sx = chart.selected * slot + slot / 2;
    final sh = values[chart.selected] / maxV * (base - top);
    canvas.drawLine(
      Offset(sx, 44),
      Offset(sx, base - math.max(sh, 3)),
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = 1.5,
    );
    final big = _text(
      chart.valueLabel,
      AppText.style(22, AppText.w800, spacingPercent: -2),
    );
    final small = _text(
      chart.dateLabel,
      AppText.style(12, AppText.w500, color: AppColors.muted),
    );
    final w = math.max(big.width, small.width);
    final leftSide = sx - w - 6 >= 0;
    final x = leftSide ? sx - 6 : sx + 6;
    big.paint(canvas, Offset(leftSide ? x - big.width : x, 0));
    small.paint(canvas, Offset(leftSide ? x - small.width : x, big.height));
  }

  @override
  bool shouldRepaint(covariant _WeekPainter old) =>
      old.chart.selected != chart.selected ||
      old.chart.values != chart.values ||
      old.chart.valueLabel != chart.valueLabel;
}

/// Batang tipis per tanggal satu bulan (level saldo / keluar per hari).
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({
    super.key,
    required this.values,
    required this.colors,
    required this.scaleLabels,
    required this.xLabels,
    this.highlights = const {},
    this.markers = const {},
    this.markerColor = AppColors.success,
    this.pill,
  });

  /// Tinggi batang 0..1 per hari; `null` = belum lewat (tidak digambar).
  final List<double?> values;
  final List<Color> colors;

  /// Label kanan atas → bawah, mis. ["100%", "50%", "0%"].
  final List<String> scaleLabels;

  /// Indeks hari → label bawah; label "Hari ini" ditebalkan.
  final Map<int, String> xLabels;

  /// Hari yang diberi latar lembut (ada uang masuk).
  final Set<int> highlights;

  /// Hari yang diberi ikon petir di atas.
  final Set<int> markers;
  final Color markerColor;

  /// Pil nilai di atas batang yang dipotong skala, mis. (0, "1,2jt").
  final (int, String)? pill;

  static const height = 150.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final slot = (c.maxWidth - _rightAxis) / values.length;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _DailyPainter(this))),
              for (final i in markers)
                Positioned(
                  left: i * slot + slot / 2 - 6,
                  top: 4,
                  child: Icon(LucideIcons.zap, size: 12, color: markerColor),
                ),
              if (pill case (final i, final label))
                Positioned(
                  left: math.max(0, i * slot + slot / 2 - 18),
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      label,
                      style: AppText.style(
                        10,
                        AppText.w800,
                        color: AppColors.lime,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DailyPainter extends CustomPainter {
  _DailyPainter(this.chart);

  final DailyBarChart chart;

  static const top = 22.0, base = 128.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = chart.values.length;
    final area = size.width - _rightAxis;
    final slot = area / n;
    final bw = slot * 0.7;
    final mid = (top + base) / 2;
    for (final i in chart.highlights) {
      canvas.drawRect(
        Rect.fromLTWH(i * slot, top, slot, base - top),
        Paint()..color = const Color(0xFFE2F6EC),
      );
    }
    _dashed(canvas, top, area);
    _dashed(canvas, mid, area);
    _dashed(canvas, base, area, solid: true);
    final axis = AppText.style(10, AppText.w500, color: AppColors.faint);
    for (final (i, y) in [top, mid, base].indexed) {
      if (i >= chart.scaleLabels.length) break;
      final t = _text(chart.scaleLabels[i], axis);
      t.paint(canvas, Offset(area + 6, y - t.height / 2));
    }
    for (var i = 0; i < n; i++) {
      final v = chart.values[i];
      if (v == null) continue;
      final h = math.max(3.0, v.clamp(0.0, 1.0) * (base - top));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * slot + (slot - bw) / 2, base - h, bw, h),
          const Radius.circular(2),
        ),
        Paint()..color = chart.colors[i],
      );
    }
    for (final MapEntry(key: i, value: label) in chart.xLabels.entries) {
      final today = label == 'Hari ini';
      final t = _text(
        label,
        AppText.style(
          10,
          today ? AppText.w800 : AppText.w500,
          color: today ? AppColors.ink : AppColors.faint,
        ),
      );
      final x = (i * slot + slot / 2 - t.width / 2).clamp(0.0, area - t.width);
      t.paint(canvas, Offset(x, base + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _DailyPainter old) => true;
}
