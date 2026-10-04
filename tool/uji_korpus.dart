// Ukur akurasi parser struk pada korpus OCR asli (test/fixtures/struk).
//   dart run tool/uji_korpus.dart          → ringkasan + daftar yang meleset
//   dart run tool/uji_korpus.dart cord-test-050   → baris & hasil satu struk
import 'dart:convert';
import 'dart:io';

import 'package:catat/domain/receipt_parser.dart';

void main(List<String> args) {
  final korpus = (jsonDecode(
    File('test/fixtures/struk/korpus.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  var ok = 0, dateOk = 0, dateN = 0, merchOk = 0, merchN = 0, keyword = 0;
  final misses = <String>[];
  for (final s in korpus) {
    final id = s['id'] as String;
    if (args.isNotEmpty && !args.contains(id)) continue;
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
    final now = DateTime.parse(expect['now'] as String? ?? '2019-06-01T12:00');
    final r = parseReceipt(rows, now: now);
    final good = r.total == expect['total'];
    if (good) ok++;
    if (r.totalFromKeyword && good) keyword++;
    if (expect['date'] != null) {
      dateN++;
      // Tanggalnya saja: jam di struk sering salah baca satu digit.
      final want = DateTime.parse(expect['date'] as String);
      final got = r.date;
      if (got != null &&
          got.year == want.year &&
          got.month == want.month &&
          got.day == want.day) {
        dateOk++;
      }
    }
    if (expect['merchant'] != null) {
      merchN++;
      if (r.merchant == expect['merchant']) merchOk++;
    }
    if (!good) misses.add('$id: dapat ${r.total} harusnya ${expect['total']}');
    if (args.isNotEmpty) {
      stdout.writeln(rows.map((e) => '  | $e').join('\n'));
      stdout.writeln(
        '→ total ${r.total} (kata kunci: ${r.totalFromKeyword}), toko ${r.merchant}, '
        'tgl ${r.date}, item ${r.items}',
      );
    }
  }
  final n = args.isEmpty ? korpus.length : args.length;
  stdout.writeln('Total benar: $ok/$n (${(ok * 100 / n).toStringAsFixed(1)}%)');
  stdout.writeln('  …dari baris TOTAL (bisa foto otomatis): $keyword/$n');
  if (dateN > 0) stdout.writeln('Tanggal benar: $dateOk/$dateN');
  if (merchN > 0) stdout.writeln('Toko benar: $merchOk/$merchN');
  if (args.isEmpty) stdout.writeln(misses.join('\n'));
}
