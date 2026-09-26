import 'dart:typed_data';

import '../../core/format.dart';
import '../../domain/pocket_config.dart';
import '../../domain/report.dart';
import 'xlsx_writer.dart';

/// Laporan Excel: Ringkasan, Pengeluaran, Pemasukan (bisa diolah lagi).
Uint8List buildReportXlsx(ReportData data, {required DateTime createdAt}) {
  final summary = <List<Object?>>[
    ['Laporan catat.', data.range.label],
    ['Dibuat', createdAt],
    [],
    ['Total keluar', data.totalSpent],
    [data.incomeLabel, data.totalIncome],
    ['Sisa', data.remaining],
    [],
    ['Kantong', 'Tipe', 'Jatah', 'Terpakai', 'Sisa'],
    for (final p in data.pockets)
      [
        p.pocket.name,
        pocketTypeLabel(p.pocket.type),
        p.budget,
        p.spent,
        p.budget - p.spent,
      ],
  ];
  final pocketHeader = 7;
  final bold = {0, 3, 4, 5, pocketHeader};
  if (data.months.length > 1) {
    summary
      ..add([])
      ..add(['Bulan', 'Masuk', 'Keluar', 'Sisa']);
    bold.add(summary.length - 1);
    for (final m in data.months) {
      summary.add([
        monthYearLong(m.month),
        m.income,
        m.spent,
        m.income - m.spent,
      ]);
    }
  }

  final expenses = <List<Object?>>[
    [
      'Tanggal',
      'Judul',
      'Toko',
      'Kantong',
      'Tipe',
      'Nominal',
      'Sumber',
      'Item',
      'Catatan',
    ],
    for (final e in data.expenses)
      [
        e.occurredAt,
        e.title,
        e.merchant,
        e.pocket.name,
        pocketTypeLabel(e.pocket.type),
        e.amount,
        e.source.label,
        e.items.isEmpty
            ? null
            : e.items.map((i) => '${i.name} x${i.qty} (${i.price})').join('; '),
        e.note,
      ],
    [],
    [null, null, null, null, 'Total', data.totalSpent],
  ];

  final incomes = <List<Object?>>[
    ['Tanggal', 'Keterangan', 'Nominal', 'Otomatis'],
    for (final i in data.incomes)
      [i.occurredAt, i.title, i.amount, i.auto ? 'Ya' : 'Tidak'],
    [],
    [null, 'Total', data.totalIncome],
  ];

  return buildXlsx([
    XlsxSheet(
      'Ringkasan',
      rows: summary,
      widths: const [22, 18, 16, 16, 16],
      boldRows: bold,
    ),
    XlsxSheet(
      'Pengeluaran',
      rows: expenses,
      widths: const [18, 28, 20, 18, 12, 14, 12, 40, 24],
      boldRows: {0, expenses.length - 1},
    ),
    XlsxSheet(
      'Pemasukan',
      rows: incomes,
      widths: const [18, 28, 14, 10],
      boldRows: {0, incomes.length - 1},
    ),
  ]);
}
