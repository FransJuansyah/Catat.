import 'dart:convert';
import 'dart:io';

import 'package:catat/domain/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Akurasi scan struk pada hasil OCR asli ML Kit dari HP (222 struk Indonesia,
/// lihat test/fixtures/struk/README.md). Angka minimum di bawah = hasil
/// 5 Okt 2026; kalau parser diubah dan akurasinya turun, test ini gagal.
void main() {
  final korpus = (jsonDecode(
    File('test/fixtures/struk/korpus.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  ReceiptData read(Map<String, dynamic> s) {
    final expect = s['expect'] as Map<String, dynamic>;
    final rows = groupRows([
      for (final l in s['lines'] as List)
        OcrLine(
          l[0] as String,
          (l[1] as num).toDouble(),
          (l[2] as num).toDouble(),
          (l[3] as num).toDouble(),
          (l[4] as num).toDouble(),
        ),
    ]);
    return parseReceipt(
      rows,
      now: DateTime.parse(expect['now'] as String? ?? '2019-06-01T12:00'),
    );
  }

  test('total benar minimal 94% struk', () {
    var ok = 0;
    final misses = <String>[];
    for (final s in korpus) {
      final want = (s['expect'] as Map)['total'];
      final got = read(s).total;
      if (got == want) {
        ok++;
      } else {
        misses.add('${s['id']}: $got ≠ $want');
      }
    }
    expect(
      ok / korpus.length,
      greaterThanOrEqualTo(0.94),
      reason: '$ok/${korpus.length} benar. Meleset:\n${misses.join('\n')}',
    );
  });

  test('foto otomatis (TOTAL kebaca & benar) minimal 90% struk', () {
    final locked = korpus.where((s) {
      final r = read(s);
      return r.totalFromKeyword && r.total == (s['expect'] as Map)['total'];
    }).length;
    expect(locked / korpus.length, greaterThanOrEqualTo(0.90));
  });

  test('tanggal & toko dari struk Lawson dan EDC BCA', () {
    final byId = {for (final s in korpus) s['id']: s};
    final lawson = read(byId['commons-01']!);
    expect(lawson.merchant, 'Lawson');
    expect(lawson.date, DateTime(2025, 9, 2, 17, 22));
    final edc = read(byId['commons-02']!);
    expect(edc.total, 79800);
    expect(edc.merchant, 'Indomaret');
    expect((edc.date!.year, edc.date!.month, edc.date!.day), (2025, 8, 28));
  });
}
