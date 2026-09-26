import 'receipt_parser.dart';

/// Hasil baca slip gaji (layar 08 → 02). Semua bisa null: user isi manual.
class PayslipData {
  const PayslipData({this.netSalary, this.payday});

  /// Gaji bersih / take home pay, rupiah.
  final int? netSalary;

  /// Tanggal gajian (1–31), dari tanggal pembayaran di slip.
  final int? payday;

  bool get isEmpty => netSalary == null && payday == null;
}

// Urutan = prioritas: label yang paling pasti "yang diterima" dulu.
final _netKeys = [
  RegExp(r'\bGAJI\s*BERSIH\b'),
  RegExp(r'\bTAKE\s*HOME\s*PAY\b'),
  RegExp(r'\bT\.?H\.?P\b'),
  RegExp(r'\bPENERIMAAN\s*BERSIH\b'),
  RegExp(r'\bPENDAPATAN\s*BERSIH\b'),
  RegExp(r'\bNET+\s*(PAY|SALARY|INCOME)\b'),
  RegExp(r'\bGAJI\s*NET+O?\b'),
  RegExp(r'\b(TOTAL|JUMLAH|JML)\s*(YANG\s*)?DITERIMA\b'),
  RegExp(r'\b(YANG\s*)?DITERIMA\b'),
  RegExp(r'\bTOTAL\s*TRANSFER\b'),
  RegExp(r'\bNET+O\b'),
];

// Baris yang menyebut kata kunci tapi bukan gaji bersih.
final _notNet = RegExp(
  r'BRUTO|GROSS|KOTOR|POTONGAN|DEDUCTION|PPH|PAJAK|TAX|BPJS|TERBILANG',
);

final _paydayKeys = RegExp(
  r'TANGGAL\s*(PEMBAYARAN|BAYAR|TRANSFER|GAJIAN|DIBAYAR)|TGL\.?\s*(BAYAR|TRANSFER|GAJIAN|PEMBAYARAN)|PAY(MENT)?\s*DATE|PAID\s*ON|DIBAYARKAN',
);

/// Gaji bulanan masuk akal (bukan kode karyawan / NPWP / tahun).
bool _plausibleSalary(int v) => v >= 100000 && v <= 999999999;

String _norm(String s) => s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

/// Baca slip gaji dari baris-baris teks OCR (sudah digabung per baris).
PayslipData parsePayslip(List<String> rows) {
  final upper = [for (final r in rows) _norm(r)];
  return PayslipData(
    netSalary: _findNet(rows, upper),
    payday: _findPayday(rows, upper),
  );
}

int? _findNet(List<String> rows, List<String> upper) {
  for (final key in _netKeys) {
    for (var i = 0; i < rows.length; i++) {
      final match = key.firstMatch(upper[i]);
      // "Gaji bruto" di depan label = kolom lain; "(setelah pajak)" di
      // belakang label masih gaji bersih.
      if (match == null ||
          _notNet.hasMatch(upper[i].substring(0, match.start))) {
        continue;
      }
      // Nominal di kanan label; kalau tidak ada, label & angka bertumpuk.
      final same = amountsIn(upper[i].substring(match.end))
          .where(_plausibleSalary);
      if (same.isNotEmpty) return same.first;
      if (i + 1 < rows.length && !_notNet.hasMatch(upper[i + 1])) {
        final next = amountsIn(upper[i + 1]).where(_plausibleSalary);
        if (next.isNotEmpty) return next.first;
      }
    }
  }
  return null;
}

const _months = {
  'JAN': 1,
  'FEB': 2,
  'MAR': 3,
  'APR': 4,
  'MEI': 5,
  'MAY': 5,
  'JUN': 6,
  'JUL': 7,
  'AGU': 8,
  'AGT': 8,
  'AUG': 8,
  'SEP': 9,
  'OKT': 10,
  'OCT': 10,
  'NOV': 11,
  'DES': 12,
  'DEC': 12,
};

final _ymd = RegExp(r'\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b');
final _dmy = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b');
final _named = RegExp(
  r'\b(\d{1,2})\s*[-\s]?\s*(JAN|FEB|MAR|APR|MEI|MAY|JUN|JUL|AGU|AGT|AUG|SEP|OKT|OCT|NOV|DES|DEC)[A-Z]*\.?\s*[-\s]?\s*\d{2,4}\b',
);

/// Hari dalam bulan dari tanggal pertama di [text]; null kalau tidak valid.
int? _dayIn(String text) {
  int? valid(int m, int d) => m >= 1 && m <= 12 && d >= 1 && d <= 31 ? d : null;
  if (_ymd.firstMatch(text) case final m?) {
    return valid(int.parse(m[2]!), int.parse(m[3]!));
  }
  if (_dmy.firstMatch(text) case final m?) {
    return valid(int.parse(m[2]!), int.parse(m[1]!));
  }
  if (_named.firstMatch(text) case final m?) {
    return valid(_months[m[2]!.substring(0, 3)]!, int.parse(m[1]!));
  }
  return null;
}

/// Hanya dari label tanggal bayar. Tanggal periode ("1 Sep – 30 Sep") atau
/// tanggal cetak bukan tanggal gajian, jadi tidak ditebak.
int? _findPayday(List<String> rows, List<String> upper) {
  for (var i = 0; i < rows.length; i++) {
    final match = _paydayKeys.firstMatch(upper[i]);
    if (match == null) continue;
    final day =
        _dayIn(upper[i].substring(match.end)) ??
        (i + 1 < rows.length ? _dayIn(upper[i + 1]) : null);
    if (day != null) return day;
  }
  return null;
}
