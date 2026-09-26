import 'package:catat/domain/payslip_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gaji bersih', () {
    test('slip kantor: pendapatan, potongan, gaji bersih', () {
      final slip = parsePayslip([
        'PT MAJU JAYA SENTOSA',
        'SLIP GAJI  SEPTEMBER 2026',
        'NIK  2019045512',
        'Periode  01/09/2026 - 30/09/2026',
        'Gaji Pokok  Rp 6.000.000',
        'Tunjangan Transport  Rp 750.000',
        'Total Pendapatan (Bruto)  Rp 7.100.000',
        'BPJS Kesehatan  Rp 60.000',
        'PPh 21  Rp 540.000',
        'Total Potongan  Rp 600.000',
        'Gaji Bersih  Rp 6.500.000',
        'Terbilang: enam juta lima ratus ribu rupiah',
      ]);
      expect(slip.netSalary, 6500000);
    });

    test('take home pay, format IDR dengan desimal', () {
      final slip = parsePayslip([
        'PAYSLIP  AUG 2026',
        'Gross Salary  IDR 12,500,000.00',
        'Tax (PPh 21)  IDR 1,250,000.00',
        'Take Home Pay  IDR 10,875,000.00',
      ]);
      expect(slip.netSalary, 10875000);
    });

    test('label & nominal bertumpuk (baris berikutnya)', () {
      final slip = parsePayslip([
        'Jumlah Potongan',
        '350.000',
        'Total Diterima',
        '4.150.000',
      ]);
      expect(slip.netSalary, 4150000);
    });

    test('THP & gaji netto', () {
      expect(parsePayslip(['THP  5.250.000']).netSalary, 5250000);
      expect(parsePayslip(['Gaji Netto  Rp3.900.000']).netSalary, 3900000);
      expect(parsePayslip(['Net Pay  8,000,000']).netSalary, 8000000);
    });

    test('gaji bersih lebih dipercaya dari "diterima" lain', () {
      final slip = parsePayslip([
        'Tunjangan diterima  Rp 500.000',
        'Gaji Bersih  Rp 5.500.000',
      ]);
      expect(slip.netSalary, 5500000);
    });

    test('kolom bruto di depan label tidak dianggap gaji bersih', () {
      final slip = parsePayslip([
        'Gaji Bruto  7.000.000  Netto',
        'Gaji Bersih  6.100.000',
      ]);
      expect(slip.netSalary, 6100000);
    });

    test('keterangan setelah label tetap terbaca', () {
      final slip = parsePayslip(['Gaji Bersih (setelah pajak)  Rp 4.800.000']);
      expect(slip.netSalary, 4800000);
    });

    test('tanpa label gaji bersih: tidak menebak', () {
      final slip = parsePayslip([
        'Gaji Pokok  Rp 6.000.000',
        'Total  Rp 6.000.000',
      ]);
      expect(slip.netSalary, isNull);
      expect(slip.isEmpty, isTrue);
    });

    test('angka kecil / NIK tidak dianggap gaji', () {
      final slip = parsePayslip(['Gaji Bersih  No. 12', '2026']);
      expect(slip.netSalary, isNull);
    });
  });

  group('tanggal gajian', () {
    test('dari tanggal pembayaran', () {
      final slip = parsePayslip([
        'Periode  01/09/2026 - 30/09/2026',
        'Tanggal Pembayaran  25/09/2026',
      ]);
      expect(slip.payday, 25);
    });

    test('format nama bulan & bahasa Inggris', () {
      expect(parsePayslip(['Tgl Transfer: 28 Agustus 2026']).payday, 28);
      expect(parsePayslip(['Payment Date  2026-08-27']).payday, 27);
      expect(parsePayslip(['Pay date', '1 Sep 2026']).payday, 1);
    });

    test('tanggal periode / cetak bukan tanggal gajian', () {
      final slip = parsePayslip([
        'Periode  01/09/2026 - 30/09/2026',
        'Dicetak 30/09/2026',
      ]);
      expect(slip.payday, isNull);
    });
  });
}
