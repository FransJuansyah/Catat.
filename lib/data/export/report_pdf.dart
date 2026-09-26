import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import '../../domain/pocket_config.dart';
import '../../domain/report.dart';
import '../../domain/types.dart';

/// Font PDF (Plus Jakarta Sans dari aset aplikasi).
class ReportFonts {
  const ReportFonts({required this.regular, required this.bold});

  final ByteData regular;
  final ByteData bold;
}

/// Foto struk maksimal per laporan (supaya file tidak kebesaran).
const maxReceiptPhotos = 24;

const _ink = PdfColor.fromInt(0xFF0E0E10);
const _muted = PdfColor.fromInt(0xFF71717A);
const _line = PdfColor.fromInt(0xFFE7E7E1);
const _bg = PdfColor.fromInt(0xFFF6F6F1);
const _lime = PdfColor.fromInt(0xFFD4FF4F);
const _red = PdfColor.fromInt(0xFFE5484D);

/// Hasil PDF + jumlah halaman (ditampilkan di layar 16).
class PdfReport {
  const PdfReport(this.bytes, this.pages);

  final Uint8List bytes;
  final int pages;
}

/// Laporan PDF: ringkasan, per kantong, per bulan, pemasukan, catatan harian
/// & foto struk. [photos] = foto struk yang berhasil dibaca (path → bytes).
Future<PdfReport> buildReportPdf(
  ReportData data, {
  required ReportFonts fonts,
  required DateTime createdAt,
  Map<String, Uint8List> photos = const {},
}) async {
  final doc = pw.Document(
    title: 'Laporan catat. ${data.range.label}',
    author: 'catat.',
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(fonts.regular),
      bold: pw.Font.ttf(fonts.bold),
    ),
  );

  pw.TextStyle t(double size, {bool bold = false, PdfColor color = _ink}) =>
      pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      );

  pw.Widget sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
    child: pw.Text(text, style: t(13, bold: true)),
  );

  pw.Widget table(
    List<String> header,
    List<List<String>> rows, {
    Map<int, pw.TableColumnWidth>? widths,
    Set<int> right = const {},
  }) {
    pw.Widget cell(String s, {bool head = false, required int col}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(
            s,
            textAlign: right.contains(col) ? pw.TextAlign.right : null,
            style: t(9, bold: head, color: head ? _muted : _ink),
          ),
        );
    return pw.Table(
      columnWidths: widths,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.6),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bg),
          children: [
            for (final (i, h) in header.indexed) cell(h, head: true, col: i),
          ],
        ),
        for (final r in rows)
          pw.TableRow(
            children: [for (final (i, v) in r.indexed) cell(v, col: i)],
          ),
      ],
    );
  }

  pw.Widget stat(String label, int value, {bool highlight = false}) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: highlight ? _ink : _bg,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: t(8, color: highlight ? PdfColors.grey400 : _muted),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                rupiah(value),
                style: t(
                  13,
                  bold: true,
                  color: highlight
                      ? _lime
                      : value < 0
                      ? _red
                      : _ink,
                ),
              ),
            ],
          ),
        ),
      );

  // Pengeluaran per hari.
  final days = <DateTime, List<ReportExpense>>{};
  for (final e in data.expenses) {
    (days[DateTime(e.occurredAt.year, e.occurredAt.month, e.occurredAt.day)] ??=
            [])
        .add(e);
  }

  final withPhoto = [
    for (final e in data.expenses)
      if (e.photoPath != null && photos.containsKey(e.photoPath)) e,
  ].take(maxReceiptPhotos).toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                'catat. · Laporan ${data.range.label}',
                style: t(8, color: _muted),
              ),
            ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Dibuat ${fullDate(createdAt)} ${clock(createdAt)} dengan catat.',
            style: t(7, color: _muted),
          ),
          pw.Text(
            'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
            style: t(7, color: _muted),
          ),
        ],
      ),
      build: (ctx) => [
        pw.Row(
          children: [
            pw.Container(
              width: 22,
              height: 22,
              decoration: pw.BoxDecoration(
                color: _ink,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              alignment: pw.Alignment.center,
              child: pw.Container(
                width: 9,
                height: 9,
                decoration: const pw.BoxDecoration(
                  color: _lime,
                  shape: pw.BoxShape.circle,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text('catat.', style: t(16, bold: true)),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text('Laporan ${data.range.label}', style: t(22, bold: true)),
        pw.SizedBox(height: 4),
        pw.Text(
          '${data.expenses.length} pengeluaran · ${data.incomes.length} pemasukan',
          style: t(10, color: _muted),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            stat('Total keluar', data.totalSpent),
            pw.SizedBox(width: 8),
            stat(data.incomeLabel, data.totalIncome),
            pw.SizedBox(width: 8),
            stat('Sisa', data.remaining, highlight: true),
          ],
        ),
        sectionTitle('Per kantong'),
        table(
          ['Kantong', 'Tipe', 'Jatah', 'Terpakai', 'Sisa'],
          [
            for (final p in data.pockets)
              [
                p.pocket.name,
                pocketTypeLabel(p.pocket.type),
                rupiah(p.budget),
                rupiah(p.spent),
                rupiah(p.budget - p.spent),
              ],
          ],
          right: {2, 3, 4},
        ),
        if (data.months.length > 1) ...[
          sectionTitle('Per bulan'),
          table(
            ['Bulan', 'Masuk', 'Keluar', 'Sisa'],
            [
              for (final m in data.months)
                [
                  monthYearLong(m.month),
                  rupiah(m.income),
                  rupiah(m.spent),
                  rupiah(m.income - m.spent),
                ],
            ],
            right: {1, 2, 3},
          ),
        ],
        if (data.incomes.isNotEmpty) ...[
          sectionTitle('Pemasukan'),
          table(
            ['Tanggal', 'Keterangan', 'Nominal'],
            [
              for (final i in data.incomes)
                [fullDate(i.occurredAt), i.title, rupiah(i.amount)],
            ],
            widths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(4),
              2: pw.FlexColumnWidth(2),
            },
            right: {2},
          ),
        ],
        sectionTitle('Catatan harian'),
        if (days.isEmpty)
          pw.Text('Belum ada pengeluaran.', style: t(10, color: _muted)),
        for (final MapEntry(key: day, value: list) in days.entries) ...[
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(fullDate(day), style: t(10, bold: true)),
                pw.Text(
                  rupiahOut(list.fold<int>(0, (s, e) => s + e.amount)),
                  style: t(10, bold: true),
                ),
              ],
            ),
          ),
          table(
            ['Jam', 'Judul', 'Kantong', 'Nominal'],
            [
              for (final e in list)
                [
                  clock(e.occurredAt),
                  [
                    e.title,
                    if (e.merchant != null && e.merchant != e.title)
                      e.merchant!,
                    if (e.source != ExpenseSource.manual) e.source.name,
                    if (e.items.isNotEmpty)
                      e.items.map((i) => '${i.name} x${i.qty}').join(', '),
                  ].join(' · '),
                  e.pocket.name,
                  rupiah(e.amount),
                ],
            ],
            widths: const {
              0: pw.FixedColumnWidth(40),
              1: pw.FlexColumnWidth(5),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            right: {3},
          ),
        ],
        if (withPhoto.isNotEmpty) ...[
          pw.NewPage(),
          pw.Text('Foto struk', style: t(13, bold: true)),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in withPhoto)
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        height: 300,
                        width: 250,
                        alignment: pw.Alignment.center,
                        color: _bg,
                        child: pw.Image(
                          pw.MemoryImage(photos[e.photoPath]!),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${fullDate(e.occurredAt)} · ${e.title} · ${rupiah(e.amount)}',
                        style: t(8, color: _muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
  );

  final bytes = await doc.save();
  return PdfReport(bytes, doc.document.pdfPageList.pages.length);
}
