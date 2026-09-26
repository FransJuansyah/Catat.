import 'package:catat/domain/report.dart';
import 'package:catat/domain/types.dart';
import 'package:catat/domain/views.dart';
import 'package:flutter_test/flutter_test.dart';

/// F7: rentang laporan, nama file, insight bulan ini vs bulan lalu.
void main() {
  group('ReportRange', () {
    test('bulanan: satu bulan penuh', () {
      final r = ReportRange.of(ReportSpan.month, DateTime(2026, 9, 26));
      expect(r.start, DateTime(2026, 9));
      expect(r.end, DateTime(2026, 10));
      expect(r.label, 'September 2026');
      expect(r.shortLabel, 'Sep 2026');
      expect(r.fileName(ExportFormat.pdf), 'Laporan_catat_Sep_2026.pdf');
    });

    test('3 bulan: 2 bulan sebelumnya + bulan ini', () {
      final r = ReportRange.of(ReportSpan.quarter, DateTime(2026, 9, 26));
      expect(r.months, [
        DateTime(2026, 7),
        DateTime(2026, 8),
        DateTime(2026, 9),
      ]);
      expect(r.label, 'Juli – September 2026');
      expect(r.shortLabel, 'Jul – Sep 2026');
      expect(r.fileName(ExportFormat.excel), 'Laporan_catat_Jul-Sep_2026.xlsx');
    });

    test('3 bulan lintas tahun', () {
      final r = ReportRange.of(ReportSpan.quarter, DateTime(2027, 1, 5));
      expect(r.start, DateTime(2026, 11));
      expect(r.end, DateTime(2027, 2));
      expect(r.label, 'November 2026 – Januari 2027');
      expect(r.shortLabel, 'Nov 2026 – Jan 2027');
      expect(r.fileName(ExportFormat.pdf), 'Laporan_catat_Nov2026-Jan2027.pdf');
    });

    test('setahun: Januari–Desember', () {
      final r = ReportRange.of(ReportSpan.year, DateTime(2026, 9, 26));
      expect(r.months, hasLength(12));
      expect(r.label, 'Januari – Desember 2026');
      expect(r.shortLabel, '2026');
      expect(r.fileName(ExportFormat.pdf), 'Laporan_catat_2026.pdf');
    });
  });

  group('buildInsight', () {
    const wajib = PocketRef(
      id: 'w',
      type: PocketType.wajib,
      name: 'Kebutuhan',
      iconKey: 'home',
      color: 0,
    );
    const keinginan = PocketRef(
      id: 'k',
      type: PocketType.keinginan,
      name: 'Keinginan',
      iconKey: 'sparkle',
      color: 0,
    );
    final sep = ReportRange.of(ReportSpan.month, DateTime(2026, 9));
    final aug = ReportRange.of(ReportSpan.month, DateTime(2026, 8));

    ReportExpense expense(
      PocketRef pocket,
      int amount, {
      String title = 'Pengeluaran',
      String? merchant,
    }) => ReportExpense(
      occurredAt: DateTime(2026, 9, 10),
      title: title,
      pocket: pocket,
      amount: amount,
      source: ExpenseSource.manual,
      merchant: merchant,
    );

    ReportData data(ReportRange range, List<ReportExpense> expenses) {
      final spent = <String, int>{};
      for (final e in expenses) {
        spent[e.pocket.id] = (spent[e.pocket.id] ?? 0) + e.amount;
      }
      return ReportData(
        range: range,
        mode: IncomeMode.salary,
        pockets: [
          for (final p in [wajib, keinginan])
            PocketReport(pocket: p, spent: spent[p.id] ?? 0, budget: 0),
        ],
        months: const [],
        expenses: expenses,
        incomes: const [],
      );
    }

    test('tanpa pengeluaran: tidak ada insight', () {
      expect(buildInsight(data(sep, const []), null), isNull);
    });

    test('kantong naik: sebut persen & judul favorit', () {
      final insight = buildInsight(
        data(sep, [
          expense(keinginan, 30000, title: 'kopi susu'),
          expense(keinginan, 20000, title: 'kopi susu'),
          expense(keinginan, 62000, title: 'Nonton'),
        ]),
        data(aug, [expense(keinginan, 100000)]),
      )!;
      expect(
        insight.text,
        'Jajan Keinginan naik 12% dari Agustus. Kopi susu jadi juaranya.',
      );
      expect(insight.pocket?.id, 'k');
    });

    test('total turun: kasih pujian', () {
      final insight = buildInsight(
        data(sep, [expense(wajib, 80000)]),
        data(aug, [expense(wajib, 100000)]),
      )!;
      expect(
        insight.text,
        'Pengeluaran turun 20% dari Agustus. Mantap, pertahankan!',
      );
    });

    test('terbesar: pakai nama toko bila ada', () {
      final insight = buildInsight(
        data(sep, [
          expense(wajib, 52000, title: 'Belanja', merchant: 'Indomaret'),
          expense(keinginan, 10000),
        ]),
        null,
      )!;
      expect(
        insight.text,
        'Pengeluaran terbesar: Indomaret di kantong Kebutuhan.',
      );
    });

    test('terbesar tanpa nama: judul bawaan tidak diulang', () {
      final insight = buildInsight(
        data(sep, [expense(keinginan, 85000), expense(wajib, 52000)]),
        null,
      )!;
      expect(
        insight.text,
        'Pengeluaran terbesar bulan ini ada di kantong Keinginan.',
      );
    });
  });
}
