import 'dart:math' as math;

import 'types.dart';

/// Satu baris teks hasil OCR beserta posisinya (piksel gambar).
class OcrLine {
  const OcrLine(this.text, this.left, this.top, this.right, this.bottom);

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
}

/// Satu item belanja di struk.
class ReceiptItem {
  const ReceiptItem(this.name, this.price, {this.qty = 1});

  final String name;

  /// Harga total baris (qty × harga satuan).
  final int price;
  final int qty;

  @override
  String toString() => '$name x$qty = $price';
}

/// Hasil baca struk (layar 05).
class ReceiptData {
  const ReceiptData({
    this.merchant,
    this.date,
    this.total,
    this.items = const [],
    this.totalFromKeyword = false,
    this.text = '',
  });

  final String? merchant;

  /// Seluruh teks struk (untuk tebak kantong).
  final String text;

  /// Tanggal & jam di struk (null = tidak kebaca, pakai sekarang).
  final DateTime? date;
  final int? total;
  final List<ReceiptItem> items;

  /// Total diambil dari baris "TOTAL …" (bukan tebakan).
  final bool totalFromKeyword;

  int get itemsSum => items.fold<int>(0, (s, i) => s + i.price);

  /// Total & item saling cocok → kemungkinan besar benar.
  bool get confident =>
      total != null && totalFromKeyword && (items.isEmpty || itemsSum == total);
}

// ------------------------------------------------------------- baris

/// Gabungkan potongan OCR yang sejajar jadi satu baris struk (kiri → kanan),
/// dipisah dua spasi. ML Kit sering memisah nama item & harga jadi blok beda.
List<String> groupRows(List<OcrLine> lines) {
  final sorted = [...lines.where((l) => l.text.trim().isNotEmpty)]
    ..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<OcrLine>>[];
  for (final line in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null) {
      final center = row.fold<double>(0, (s, l) => s + l.centerY) / row.length;
      final h = math.max(line.height, row.first.height);
      final overlapsX = row.any(
        (l) => line.left < l.right - 4 && line.right > l.left + 4,
      );
      if ((line.centerY - center).abs() < h * 0.55 && !overlapsX) {
        row.add(line);
        continue;
      }
    }
    rows.add([line]);
  }
  return [
    for (final row in rows)
      ([...row]..sort((a, b) => a.left.compareTo(b.left)))
          .map((l) => l.text.trim())
          .join('  '),
  ];
}

// ------------------------------------------------------------- angka

final _amountRe = RegExp(
  r'(?<![\d.,A-Za-z])(\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,](\d{2}))?(?![\d.,]*\d)(?![A-Za-z])',
);
final _dateRe = RegExp(
  r'\b\d{1,4}[/\-.]\d{1,2}[/\-.]\d{2,4}\b|\b\d{1,2}:\d{2}(?::\d{2})?\b',
);

final _namedDateRe = RegExp(
  r'\b\d{1,2}\s*[-\s]?\s*(JAN|FEB|MAR|APR|MEI|MAY|JUN|JUL|AGU|AGT|AUG|SEP|OKT|OCT|NOV|DES|DEC)[A-Z]*\.?,?\s*[-\s]?\s*\d{2,4}\b',
  caseSensitive: false,
);

/// "36.000" / "36,000" / "36.000,00" / "Rp36000" → 36000. null kalau bukan angka.
int? parseAmount(String token) {
  final m = _amountRe.firstMatch(token.replaceAll(' ', ''));
  if (m == null) return null;
  return int.tryParse(m.group(1)!.replaceAll(RegExp('[.,]'), ''));
}

/// Semua nominal rupiah di satu baris (tanggal, jam & angka kecil dibuang).
List<int> amountsIn(String row) {
  final clean = row
      .replaceAll(_namedDateRe, ' ')
      .replaceAll(_dateRe, ' ')
      // "Rp 36.000" / "Rp.36.000"
      .replaceAll(RegExp(r'Rp\.?\s*', caseSensitive: false), ' ');
  return [
    for (final m in _amountRe.allMatches(clean))
      if (int.tryParse(m.group(1)!.replaceAll(RegExp('[.,]'), '')) case final v?
          when v >= 100 && v <= 999999999)
        v,
  ];
}

bool _hasLetters(String s, [int min = 3]) =>
    RegExp('[A-Za-z]').allMatches(s).length >= min;

String _norm(String s) => s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

/// Baris "total" yang sebenarnya bukan total belanja.
const _notTotal = [
  'ITEM',
  'QTY',
  'DISC',
  'DISKON',
  'HEMAT',
  'PPN',
  'PAJAK',
  'TAX',
  'POIN',
  'POINT',
  'KEMBALI',
  'TUNAI',
  'CASH',
  'CHANGE',
];

/// Baris yang bukan item belanja.
const _notItem = [
  'TOTAL',
  'JUMLAH',
  'TAGIHAN',
  'BAYAR',
  'TUNAI',
  'CASH',
  'KEMBALI',
  'CHANGE',
  'PPN',
  'PAJAK',
  'TAX',
  'SERVICE',
  'DISKON',
  'DISC',
  'HEMAT',
  'POTONGAN',
  'VOUCHER',
  'POIN',
  'POINT',
  'MEMBER',
  'NPWP',
  'TELP',
  'TLP',
  'HP ',
  'KASIR',
  'NO.',
  'NOMOR',
  'DEBIT',
  'KREDIT',
  'CREDIT',
  'EDC',
  'SALDO',
  'HARGA JUAL',
  'DPP',
  'NON TUNAI',
  // Struk mesin EDC bank.
  'BATCH',
  'TRACE',
  'REF',
  'APPR',
  'TERM',
  'MERC',
  'CARD TYPE',
  'AID',
  'TVR',
];

// ------------------------------------------------------------- perbaikan OCR

/// Huruf yang sering terbaca di tempat angka pada struk termal.
const _digitLike = {
  'O': '0',
  'o': '0',
  'D': '0',
  'Q': '0',
  'I': '1',
  'i': '1',
  'l': '1',
  '|': '1',
  'S': '5',
  's': '5',
  'B': '8',
  'b': '6',
  'G': '6',
  'Z': '2',
  'z': '2',
  '&': '6',
};
const _digitClass = r'[0-9OoDQIil|SsBbGZz&]';

/// Rapikan angka di satu baris struk sebelum dibaca:
/// "281, 435" → "281,435" · "118.D00" → "118.000" · "I11,000" → "111,000".
String fixOcrNumbers(String input) {
  var row = input;
  // Huruf nyangkut di belakang nominal: "18,999C" → "18,999".
  row = row.replaceAllMapped(
    RegExp(r'(\d[.,]\d{3})[A-Za-z](?![A-Za-z])'),
    (m) => '${m[1]} ',
  );
  // Ribuan dipisah spasi: "Soto Betawi  116 000" → "116000".
  row = row.replaceAllMapped(
    RegExp(r'(?<![\d.,])(\d{1,3}) (\d{3})(?![\d.,]*\d)'),
    (m) => '${m[1]}${m[2]}',
  );
  // "l591 ,600" → "l591,600"; "1591,600" → "1,591,600".
  row = row
      .replaceAllMapped(
        RegExp(r'(\d) +([.,]\d{3})(?!\d)'),
        (m) => '${m[1]}${m[2]}',
      )
      .replaceAllMapped(
        RegExp('(?<![0-9A-Za-z.,])($_digitClass)(\\d{3})([.,]\\d{3})(?!\\d)'),
        (m) => '${m[1]},${m[2]}${m[3]}',
      );
  // "Rp" salah baca jadi "Re" / "Rr" / "RP" menempel ke angka.
  var r = row.replaceAllMapped(
    RegExp(r'(?<![A-Za-z])R[pPrReE]\.?\s*(?=[0-9OoIl])'),
    (_) => 'Rp ',
  );
  r = r.replaceAllMapped(
    RegExp('(\\d{1,3}[.,])\\s($_digitClass{3})(?![0-9A-Za-z])'),
    (m) => '${m[1]}${m[2]}',
  );
  r = r.replaceAllMapped(
    RegExp(
      '(?<![A-Za-z0-9])($_digitClass{1,3}(?:[.,]$_digitClass{3})+)(?![A-Za-z0-9])',
    ),
    (m) {
      final t = m[1]!;
      // Harus kebanyakan angka: "S.SOO" bukan nominal, "1.2O0" iya.
      if (RegExp(r'\d').allMatches(t).length * 2 <
          t.replaceAll(RegExp('[.,]'), '').length) {
        return t;
      }
      return t.split('').map((c) => _digitLike[c] ?? c).join();
    },
  );
  return r;
}

/// Jarak edit (Levenshtein) kata pendek.
int _distance(String a, String b) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = <int>[i];
    for (var j = 1; j <= b.length; j++) {
      cur.add(
        [
          prev[j] + 1,
          cur[j - 1] + 1,
          prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce(math.min),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Kata-kata huruf di satu baris, angka yang nyelip di kata dibetulkan
/// ("T8TAL" → "TBTAL", "PB1" tetap utuh lewat [_raw]).
List<String> _words(String row) => [
  for (final m in RegExp(r'[A-Za-z0-9]+').allMatches(row))
    if (RegExp('[A-Za-z]').hasMatch(m[0]!))
      m[0]!
          .toUpperCase()
          .replaceAll('0', 'O')
          .replaceAll('1', 'I')
          .replaceAll('5', 'S')
          .replaceAll('8', 'B')
          .replaceAll('6', 'G')
          .replaceAll('7', 'T')
          // Angka nyangkut di depan kata: "3TOTAL" → "TOTAL".
          .replaceFirst(RegExp(r'^\d+(?=[A-Z])'), ''),
];

bool _like(String word, String key, {int? maxEdits}) {
  final edits =
      maxEdits ??
      (key.length >= 7
          ? 2
          : key.length >= 4
          ? 1
          : 0);
  if ((word.length - key.length).abs() > edits) return false;
  return _distance(word, key) <= edits;
}

// ------------------------------------------------------------- jenis baris

enum _Kind {
  grandTotal,
  total,
  subtotal,
  tax,
  service,
  discount,
  cash,
  change,
  itemCount,
  itemTotal,
  other,
}

bool _isTotalWord(String w) =>
    w.length >= 4 && w.length <= 6 && _like(w, 'TOTAL') ||
    // "Totabswuuousn": huruf sisa garis/cap nempel di belakang.
    w.length > 6 && w.startsWith('TOTA') && !w.startsWith('TOTALITAS') ||
    w == 'TTL' ||
    w == 'TL' ||
    w == 'TOT';

_Kind _kindOf(String row) {
  final w = _words(row);
  if (w.isEmpty) return _Kind.other;
  final raw = _norm(row);
  bool any(bool Function(String) f) => w.any(f);
  bool has(String key, {int? edits}) =>
      any((x) => _like(x, key, maxEdits: edits));

  var totalAt = w.indexWhere(_isTotalWord);
  // Kata terpecah: "TO TAL".
  for (var i = 0; totalAt < 0 && i + 1 < w.length; i++) {
    if (_isTotalWord(w[i] + w[i + 1])) totalAt = i + 1;
  }
  final hasTotal = totalAt >= 0 || w.contains('DUE');
  if (has('SUBTOTAL') ||
      (any((x) => x == 'NET' || x == 'NETT') && (has('SALES') || hasTotal)) ||
      has('SUBTTL') ||
      (totalAt > 0 && _like(w[totalAt - 1], 'SUB', maxEdits: 1))) {
    return _Kind.subtotal;
  }
  // "Total Item 3" / "Qty 2" = jumlah barang, bukan uang. "TOTAL (2 item)
  // 120,000" / "PCS 3  DUE 24,500" bisa jadi total kalau tidak ada yang lain.
  if (any(
    (x) =>
        _like(x, 'ITEM') ||
        _like(x, 'ITEMS') ||
        x == 'TEMS' ||
        x == 'QTY' ||
        x == 'PCS',
  )) {
    return hasTotal ? _Kind.itemTotal : _Kind.itemCount;
  }
  if (has('DISC') ||
      has('DISCOUNT') ||
      has('DISKON') ||
      has('POTONGAN') ||
      has('VOUCHER') ||
      has('KUPON') ||
      has('COUPON') ||
      has('PROMO') ||
      has('HEMAT')) {
    return _Kind.discount;
  }
  final taxWord =
      any(
        (x) => const {
          'PPN',
          'TAX',
          'PAJAK',
          'PBI',
          'PB',
          'PBL',
          'VAT',
          'REST',
          'RESTO',
        }.contains(x),
      ) ||
      RegExp(r'\bP\s?B\s?[1I]\b').hasMatch(raw);
  if (taxWord) {
    // "TOTAL (TERMASUK PAJAK)" tetap total.
    return hasTotal && RegExp('INCL|TERMASUK|SUDAH').hasMatch(raw)
        ? _Kind.total
        : _Kind.tax;
  }
  if (has('SERVICE') ||
      has('SERVIS') ||
      any((x) => x == 'SVC' || x == 'SC' || x == 'SERV')) {
    return _Kind.service;
  }
  // "CHARGE" (service charge) beda satu huruf dengan "CHANGE".
  if (has('KEMBALI') ||
      has('KEMBALIAN') ||
      (has('CHANGE') && !w.contains('CHARGE')) ||
      (has('CHANGED') && !w.contains('CHARGE')) ||
      any((x) => x == 'CG' || x == 'KBL' || x == 'KMBL')) {
    return _Kind.change;
  }
  if (any((x) => _like(x, 'GRAND') || x == 'GND' || x == 'GRD') &&
      (hasTotal || any((x) => _like(x, 'TOTAL', maxEdits: 2)))) {
    return _Kind.grandTotal;
  }
  if (hasTotal ||
      has('JUMLAH') ||
      has('TAGIHAN') ||
      has('AMOUNT') ||
      raw.contains('HARUS DIBAYAR') ||
      raw.contains('TOTAL BAYAR')) {
    return _Kind.total;
  }
  if (any(
    (x) =>
        _like(x, 'CASH') ||
        _like(x, 'TUNAI') ||
        x == 'PAY' ||
        x == 'PAID' ||
        x == 'BAYAR' ||
        _like(x, 'DEBIT') ||
        _like(x, 'KREDIT') ||
        _like(x, 'CREDIT') ||
        x == 'CARD' ||
        x == 'QRIS' ||
        x == 'EDC' ||
        x == 'GOPAY' ||
        x == 'OVO' ||
        x == 'SHOPEEPAY' ||
        x == 'DANA' ||
        x == 'BCA' ||
        x == 'MANDIRI' ||
        x == 'BRI' ||
        x == 'BNI',
  )) {
    return _Kind.cash;
  }
  return _Kind.other;
}

// ------------------------------------------------------------- total

/// Nominal milik baris [i]: di baris itu, atau baris sebelah (bawah dulu,
/// lalu atas) kalau baris itu cuma angka (kolom harga kebaca terpisah).
/// Angka dalam kurung ("PB1 (10%)") bukan nominal.
List<int> _valuesAt(List<String> rows, int i) {
  List<int> clean(String row) {
    final text = row.replaceAll(RegExp(r'\([^)]{0,8}\)'), ' ');
    final found = amountsIn(text);
    if (found.isNotEmpty) return found;
    // Digit terakhir struk termal sering hilang: "19,50" = 19.500.
    return [
      for (final m in RegExp(
        r'(?<![\d.,])(\d{1,3})[.,](\d{1,2})(?![\d.,]*\d)(?!\s*%)',
      ).allMatches(text))
        if (int.parse(m[1]!) > 0)
          int.parse(m[1]!) * 1000 + int.parse(m[2]!.padRight(3, '0')),
    ];
  }

  final here = clean(rows[i]);
  if (here.isNotEmpty) return here;
  for (final j in [i + 1, i - 1]) {
    if (j < 0 || j >= rows.length || _hasLetters(rows[j], 2)) continue;
    final there = clean(rows[j]);
    if (there.isNotEmpty) return there;
  }
  return const [];
}

class _Totals {
  int? total;
  int? totalIndex;
  int? subtotal;
  int? subtotalIndex;
  int tax = 0;
  int service = 0;
  int discount = 0;
  int? cash;
  int? change;
  int? firstSummaryIndex;
  bool cashIsCard = false;
}

_Totals _scanTotals(List<String> rows) {
  final t = _Totals();
  int? grand, grandIndex, itemTotal, itemTotalIndex;
  final totals = <(int, int)>[];
  // (indeks, jenis, nominal) pajak / service / diskon.
  final adjustments = <(int, _Kind, int)>[];
  for (var i = 0; i < rows.length; i++) {
    final kind = _kindOf(rows[i]);
    if (kind == _Kind.other || kind == _Kind.itemCount) continue;
    if (kind != _Kind.cash) t.firstSummaryIndex ??= i;
    final v = _valuesAt(rows, i);
    switch (kind) {
      case _Kind.grandTotal:
        if (v.isNotEmpty && grand == null) {
          grand = v.last;
          grandIndex = i;
        }
      case _Kind.total:
        if (v.isNotEmpty) totals.add((i, v.last));
      case _Kind.itemTotal:
        if (v.isNotEmpty && itemTotal == null) {
          itemTotal = v.last;
          itemTotalIndex = i;
        }
      case _Kind.subtotal:
        if (v.isNotEmpty && t.subtotal == null) {
          t.subtotal = v.last;
          t.subtotalIndex = i;
        }
      case _Kind.tax || _Kind.service || _Kind.discount:
        if (v.isNotEmpty) adjustments.add((i, kind, v.last));
      case _Kind.change:
        // "Pay Cash 100,000  Change :60,000" di satu baris.
        if (v.length >= 2 && t.cash == null) t.cash = v.first;
        if (v.isNotEmpty) t.change ??= v.last;
        if (v.isEmpty && RegExp(r'\b0\b').hasMatch(rows[i])) t.change ??= 0;
      case _Kind.cash:
        if (v.isNotEmpty && t.cash == null) {
          t.cash = v.last;
          t.cashIsCard = !RegExp(
            'CASH|TUNAI|CASK',
            caseSensitive: false,
          ).hasMatch(rows[i]);
        }
      case _Kind.itemCount || _Kind.other:
        break;
    }
  }
  if (t.subtotal != null) {
    for (final (i, kind, v) in adjustments) {
      if (kind != _Kind.discount && v > t.subtotal!) totals.add((i, v));
    }
    adjustments.removeWhere(
      (a) => a.$2 != _Kind.discount && a.$3 > t.subtotal!,
    );
  }
  // Baris total pertama yang masuk akal ("AMOUNT 3.636" pajak dilewati):
  // total jauh di bawah subtotal = angka baris lain yang kecomot.
  for (final (i, v) in totals) {
    if (t.subtotal != null && v * 2 < t.subtotal!) continue;
    t.total = v;
    t.totalIndex = i;
    break;
  }
  // Grand total yang lebih kecil dari subtotal = salah baca.
  if (grand != null && (t.subtotal == null || grand >= t.subtotal!)) {
    t.total = grand;
    t.totalIndex = grandIndex;
  }
  // "TOTAL (2 item) 120,000" dipakai kalau tidak ada baris total lain.
  if (t.total == null && itemTotal != null) {
    t.total = itemTotal;
    t.totalIndex = itemTotalIndex;
  }
  // Pajak/service/diskon dihitung di antara subtotal & total saja: "Coupon"
  // sesudah total = cara bayar, bukan potongan.
  for (final (i, kind, v) in adjustments) {
    if (t.subtotalIndex != null && i < t.subtotalIndex!) continue;
    if (t.totalIndex != null && i > t.totalIndex!) continue;
    switch (kind) {
      case _Kind.tax:
        t.tax += v;
      case _Kind.service:
        t.service += v;
      default:
        t.discount += v;
    }
  }
  return t;
}

/// Nominal di [row] yang memuat "?" (digit tak kebaca) cocok dengan [value].
bool _matchesUnreadDigits(String row, int value) {
  final digits = '$value';
  for (final m in RegExp(r'[\d?][\d?.,]*[\d?]').allMatches(row)) {
    final token = m[0]!.replaceAll(RegExp('[.,]'), '');
    if (!token.contains('?') || token.length != digits.length) continue;
    var ok = true;
    for (var i = 0; i < token.length && ok; i++) {
      ok = token[i] == '?' || token[i] == digits[i];
    }
    if (ok) return true;
  }
  return false;
}

/// Pilih total paling meyakinkan dengan cek silang hitungan struk.
({int? amount, bool keyword, int? end}) _decideTotal(List<String> rows) {
  final t = _scanTotals(rows);
  // Item berhenti di baris ringkasan pertama (subtotal/total/pajak).
  final end = t.firstSummaryIndex ?? t.totalIndex;
  final fromCash = t.cash != null && t.change != null && t.cash! > t.change!
      ? t.cash! - t.change!
      : null;
  final fromSub = t.subtotal == null
      ? null
      : t.subtotal! + t.tax + t.service - t.discount;
  bool round(int v) => v % 100 == 0;
  bool near(int a, int b) => (a - b).abs() <= math.max(100, b * 0.02);

  final total = t.total;
  if (total != null) {
    if (total == fromCash || total == fromSub || total == t.cash) {
      return (amount: total, keyword: true, end: end);
    }
    // "17,9?9": digit yang tak kebaca cocok dengan hitungan → pakai hitungan.
    final row = rows[t.totalIndex!];
    for (final other in [fromSub, fromCash]) {
      if (other != null && _matchesUnreadDigits(row, other)) {
        return (amount: other, keyword: true, end: end);
      }
    }
    // Dua hitungan lain sepakat → angka TOTAL salah baca.
    if (fromCash != null && fromCash == fromSub) {
      return (amount: fromCash, keyword: true, end: end);
    }
    if (fromCash != null &&
        fromSub != null &&
        near(fromCash, fromSub) &&
        !near(total, fromCash)) {
      return (amount: fromCash, keyword: true, end: end);
    }
    // Bayar kartu tanpa kembalian = total; TOTAL terpotong ("5,000").
    if (t.cashIsCard && t.change == null && total * 2 < t.cash!) {
      return (amount: t.cash, keyword: true, end: end);
    }
    for (final other in [fromSub, fromCash]) {
      if (other != null &&
          near(total, other) &&
          round(other) &&
          !round(total)) {
        return (amount: other, keyword: true, end: end);
      }
    }
    return (amount: total, keyword: true, end: end);
  }
  if (fromCash != null && fromCash == fromSub) {
    return (amount: fromCash, keyword: true, end: end);
  }
  if (t.subtotal != null &&
      t.cash != null &&
      (t.cash == fromSub || t.cash == t.subtotal) &&
      (t.change ?? 0) == 0) {
    return (amount: t.cash, keyword: true, end: end);
  }
  // Uang dibayar tanpa kembalian, sedikit di atas hitungan subtotal (pajak
  // yang labelnya tak kebaca) = total.
  if (fromSub != null &&
      t.cash != null &&
      t.change == null &&
      t.cash! >= fromSub &&
      t.cash! <= fromSub * 1.25) {
    return (amount: t.cash, keyword: true, end: end);
  }
  if (fromSub != null) return (amount: fromSub, keyword: false, end: end);
  if (fromCash != null) return (amount: fromCash, keyword: false, end: end);
  if (t.cash != null && (t.cashIsCard || t.change == 0)) {
    return (amount: t.cash, keyword: false, end: end);
  }
  return (amount: null, keyword: false, end: end);
}

// ------------------------------------------------------------- item

final _qtyRe = RegExp(
  r'(?:\b[xX]\s?(\d{1,2})\b|\b(\d{1,2})\s?[xX]\b|\b(\d{1,2})\s?(?:PCS|pcs|Pcs|BH|bh)\b)',
);

String _cleanName(String s) {
  final name = s
      .replaceAll(_qtyRe, ' ')
      .replaceAll(RegExp(r'^\s*\d{1,2}\s+'), ' ')
      .replaceAll(RegExp(r'[@:]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return _titleCase(name);
}

/// Satu baris item: nama di kiri, harga total paling kanan.
ReceiptItem? _parseItem(String row) {
  final upper = _norm(row);
  if (_notItem.any(upper.contains) || _kindOf(row) != _Kind.other) return null;
  final amounts = amountsIn(row);
  if (amounts.isEmpty) return null;
  // Bagian nama = sebelum angka pertama yang bukan bagian nama (mis. "1L").
  final firstNum = RegExp(r'\s{2,}|\s(?=\d[\d.,]*\s|\d[\d.,]*$)')
      .firstMatch(row);
  final namePart = firstNum == null ? row : row.substring(0, firstNum.start);
  if (!_hasLetters(namePart)) return null;

  final price = amounts.last;
  var qty = 1;
  final lead = RegExp(r'^\s*(\d{1,2})\s+[A-Za-z]').firstMatch(row);
  final q = _qtyRe.firstMatch(row);
  if (q != null) {
    qty = int.parse(q.group(1) ?? q.group(2) ?? q.group(3)!);
  } else if (lead != null) {
    // Gaya restoran: "2 Es Teh  10,000".
    qty = int.parse(lead.group(1)!);
  } else {
    // Gaya Indomaret: "NAMA  2  18,000  36,000" → qty × satuan = total.
    final ints = RegExp(r'(?<=\s)(\d{1,2})(?=\s)')
        .allMatches(row.substring(namePart.length))
        .map((m) => int.parse(m.group(1)!));
    for (final n in ints) {
      if (n > 1 &&
          amounts.length >= 2 &&
          amounts[amounts.length - 2] * n == price) {
        qty = n;
        break;
      }
    }
  }
  final name = _cleanName(namePart);
  if (name.length < 2) return null;
  return ReceiptItem(name, price, qty: qty.clamp(1, 99));
}

List<ReceiptItem> _findItems(List<String> rows, int end) {
  final items = <ReceiptItem>[];
  String? pendingName;
  for (var i = 0; i < end; i++) {
    final row = rows[i];
    final item = _parseItem(row);
    if (item != null) {
      items.add(item);
      pendingName = null;
      continue;
    }
    final amounts = amountsIn(row);
    final upper = _norm(row);
    // Gaya Alfamart: nama di satu baris, "2 x 18.000  36.000" di baris bawah.
    if (pendingName != null && amounts.isNotEmpty && !_hasLetters(row, 2)) {
      final q = RegExp(r'\b(\d{1,2})\s?[xX]').firstMatch(row);
      items.add(
        ReceiptItem(
          _cleanName(pendingName),
          amounts.last,
          qty: q == null ? 1 : int.parse(q.group(1)!),
        ),
      );
      pendingName = null;
      continue;
    }
    pendingName =
        amounts.isEmpty &&
            _hasLetters(row) &&
            !_notItem.any(upper.contains) &&
            _kindOf(row) == _Kind.other
        ? row
        : null;
  }
  return items;
}

// ------------------------------------------------------------- toko

/// Nama toko/aplikasi yang sering muncul → ejaan rapi.
const _brands = {
  'INDOMARET': 'Indomaret',
  // Kode toko Indomaret di struk mesin EDC bank ("IDM F646-VILLA BINTARO").
  'IDM': 'Indomaret',
  'ALFAMART': 'Alfamart',
  'ALFAMIDI': 'Alfamidi',
  'LAWSON': 'Lawson',
  'FAMILYMART': 'FamilyMart',
  'FAMILY MART': 'FamilyMart',
  'CIRCLE K': 'Circle K',
  'SUPERINDO': 'Superindo',
  'HYPERMART': 'Hypermart',
  'TRANSMART': 'Transmart',
  'GIANT': 'Giant',
  'LOTTE': 'Lotte Mart',
  'STARBUCKS': 'Starbucks',
  'KOPI KENANGAN': 'Kopi Kenangan',
  'JANJI JIWA': 'Janji Jiwa',
  'FORE COFFEE': 'Fore Coffee',
  'MIXUE': 'Mixue',
  'CHATIME': 'Chatime',
  'KFC': 'KFC',
  "MCDONALD": "McDonald's",
  'BURGER KING': 'Burger King',
  'PIZZA HUT': 'Pizza Hut',
  'SOLARIA': 'Solaria',
  'RICHEESE': 'Richeese Factory',
  'GACOAN': 'Mie Gacoan',
  'HOKBEN': 'HokBen',
  'KIMIA FARMA': 'Kimia Farma',
  'GUARDIAN': 'Guardian',
  'WATSONS': 'Watsons',
  'CENTURY': 'Apotek Century',
  'K-24': 'Apotek K-24',
  'PERTAMINA': 'Pertamina',
  'SHELL': 'Shell',
  'GOPAY': 'GoPay',
  'GOFOOD': 'GoFood',
  'GRABFOOD': 'GrabFood',
  'GRAB': 'Grab',
  'GOJEK': 'Gojek',
  'SHOPEEFOOD': 'ShopeeFood',
  'SHOPEEPAY': 'ShopeePay',
  'SHOPEE': 'Shopee',
  'TOKOPEDIA': 'Tokopedia',
  'OVO': 'OVO',
  'DANA': 'DANA',
  'XXI': 'Cinema XXI',
  'CGV': 'CGV',
  'PLN': 'PLN',
};

final _notMerchant = RegExp(
  r'\b(JL|JLN|JALAN|TELP|TLP|NPWP|NO|WWW|HTTP|KASIR|STRUK|RECEIPT|TANGGAL|TGL|KOTA|KEC|KAB|RT|RW)\b',
);

/// Dompet digital: di bukti bayar, nama tokonya ada di baris lain.
const _wallets = {'GoPay', 'OVO', 'DANA', 'ShopeePay'};

final _paymentWords = RegExp(
  r'\b(BERHASIL|SUKSES|PEMBAYARAN|TRANSAKSI|PAYMENT|SUCCESS|BAYAR|TRANSFER|DETAIL)\b',
);

String? _brandIn(String upperRow) {
  for (final e in _brands.entries) {
    if (RegExp('\\b${RegExp.escape(e.key)}\\b').hasMatch(upperRow)) {
      return e.value;
    }
  }
  return null;
}

/// Merek yang sering muncul di kaki struk sebagai promosi ("pesan via
/// GrabFood"), jadi tidak dipakai kalau letaknya di bawah.
const _footerBrands = {
  'GoFood',
  'GrabFood',
  'Grab',
  'Gojek',
  'ShopeeFood',
  'Shopee',
  'Tokopedia',
  'PLN',
};

String? _findMerchant(List<String> rows) {
  String? wallet;
  // 1. Merek di kepala struk.
  for (final row in rows.take(8).map(_norm)) {
    final brand = _brandIn(row);
    if (brand == null) continue;
    if (!_wallets.contains(brand)) return brand;
    wallet ??= brand;
  }
  // 2. Merek di bagian lain (mis. "QRIS CPM LAWSON", kepala struk berisi
  //    nama PT).
  for (final row in rows.skip(8).map(_norm)) {
    final brand = _brandIn(row);
    if (brand != null &&
        !_wallets.contains(brand) &&
        !_footerBrands.contains(brand)) {
      return brand;
    }
  }
  // 3. Baris nama di kepala struk; nama badan usaha (PT/CV) cadangan saja.
  final limit = wallet == null ? 5 : 8;
  String? company;
  for (final row in rows.take(limit)) {
    final upper = _norm(row);
    final letters = RegExp('[A-Za-z]').allMatches(row).length;
    if (letters < 3 || letters < row.replaceAll(' ', '').length * 0.5) {
      continue;
    }
    if (_notMerchant.hasMatch(upper) ||
        _paymentWords.hasMatch(upper) ||
        _namedDateRe.hasMatch(row) ||
        _dateRe.hasMatch(row) ||
        _brandIn(upper) != null ||
        amountsIn(row).isNotEmpty) {
      continue;
    }
    var name = _titleCase(row.replaceAll(RegExp(r'\s{2,}'), ' ').trim());
    if (name.length > 30) name = name.substring(0, 30).trim();
    if (RegExp(r'^(PT|CV|UD)\b\.?').hasMatch(upper)) {
      company ??= name;
      continue;
    }
    return name;
  }
  return wallet ?? company;
}

/// "SUSU UHT 1L" → "Susu Uht 1L" (kata berangka tetap kapital: 1L, 600ML).
String _titleCase(String s) => s
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map(
      (w) => w.contains(RegExp(r'\d'))
          ? w.toUpperCase()
          : w[0].toUpperCase() + w.substring(1).toLowerCase(),
    )
    .join(' ');

// ------------------------------------------------------------- tanggal

const _monthNames = {
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

/// Semua kandidat tanggal di struk, urut posisi. Yang pertama masuk akal
/// dipakai (nomor versi "V.2025.7.0" atau nomor struk dilewati).
DateTime? _findDate(List<String> rows, DateTime now) {
  final text = rows.join('\n');
  int year(String y) => y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
  final found = <(int, DateTime?, int)>[]; // (posisi, tanggal, akhir)
  for (final m in RegExp(
    r'(?<![\d.])(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?![\d.])',
  ).allMatches(text)) {
    found.add((
      m.start,
      _safeDate(year(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
      m.end,
    ));
  }
  for (final m in RegExp(
    r'(?<![\d.])(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})(?![\d.])',
  ).allMatches(text)) {
    found.add((
      m.start,
      _safeDate(year(m[3]!), int.parse(m[2]!), int.parse(m[1]!)),
      m.end,
    ));
  }
  for (final m in RegExp(
    r'\b(\d{1,2})\s*[-\s]?\s*(JAN|FEB|MAR|APR|MEI|MAY|JUN|JUL|AGU|AGT|AUG|SEP|OKT|OCT|NOV|DES|DEC)[A-Z]*\.?,?\s*[-\s]?\s*(\d{2,4})\b',
    caseSensitive: false,
  ).allMatches(text)) {
    found.add((
      m.start,
      _safeDate(
        year(m[3]!),
        _monthNames[m[2]!.toUpperCase().substring(0, 3)]!,
        int.parse(m[1]!),
      ),
      m.end,
    ));
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (start, day, end) in found) {
    if (day == null) continue;
    // Struk dari masa depan / lebih dari setahun lalu = salah baca.
    if (day.isAfter(now) && day.difference(now).inDays >= 1) continue;
    if (now.difference(day).inDays > 400) continue;
    return _withTime(text, day, start, end);
  }
  return null;
}

/// Jam hanya dari baris tanggal (atau baris sesudahnya): jam lain di foto
/// bisa menyesatkan, mis. jam status bar pada screenshot. Tidak ada → 12:00.
DateTime _withTime(String text, DateTime day, int start, int end) {
  final timeRe = RegExp(r'\b(\d{1,2})[:.](\d{2})(?:[:.]\d{2})?\b');
  final lineStart = text.lastIndexOf('\n', start) + 1;
  var lineEnd = text.indexOf('\n', end);
  if (lineEnd >= 0) {
    final next = text.indexOf('\n', lineEnd + 1);
    lineEnd = next < 0 ? text.length : next;
  } else {
    lineEnd = text.length;
  }
  final line = text.substring(lineStart, lineEnd);
  // Jam sesudah tanggal dulu (sebelum tanggal biasanya nomor lain).
  final after = line.substring(math.min(end - lineStart, line.length));
  for (final part in [after, line]) {
    for (final t in timeRe.allMatches(part)) {
      final h = int.parse(t[1]!);
      final m = int.parse(t[2]!);
      if (h < 24 && m < 60) return DateTime(day.year, day.month, day.day, h, m);
    }
  }
  return DateTime(day.year, day.month, day.day, 12);
}

DateTime? _safeDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, m, d);
  return date.month == m ? date : null;
}

// ------------------------------------------------------------- utama

/// Baca struk dari baris-baris teks (sudah digabung per baris).
ReceiptData parseReceipt(List<String> rawRows, {required DateTime now}) {
  final rows = [for (final r in rawRows) fixOcrNumbers(r)];
  final decided = _decideTotal(rows);
  final end = decided.end ?? rows.length;
  final items = _findItems(rows, end);
  final itemsSum = items.fold<int>(0, (s, i) => s + i.price);

  var amount = decided.amount;
  if (amount == null && itemsSum > 0) amount = itemsSum;
  // "21,060" (O/G salah baca) vs item 15.000 + 6.000 = 21.000: total bulat
  // dari jumlah item lebih bisa dipercaya.
  if (amount != null &&
      amount % 100 != 0 &&
      itemsSum % 100 == 0 &&
      itemsSum > 0 &&
      (amount - itemsSum).abs() <= amount * 0.02) {
    amount = itemsSum;
  }
  if (amount == null) {
    // Terakhir: nominal terbesar, kecuali baris uang tunai/kembalian.
    final candidates = [
      for (final r in rows)
        if (!const {_Kind.cash, _Kind.change}.contains(_kindOf(r)) &&
            !_notTotal.any(_norm(r).contains))
          ...amountsIn(r),
    ];
    if (candidates.isNotEmpty) amount = candidates.reduce(math.max);
  }

  return ReceiptData(
    merchant: _findMerchant(rawRows),
    date: _findDate(rows, now),
    total: amount,
    // Item yang jumlahnya melebihi total = salah baca → jangan ditampilkan.
    items: amount != null && itemsSum > amount * 1.5 ? const [] : items,
    totalFromKeyword: decided.keyword,
    text: rawRows.join('\n'),
  );
}

// ------------------------------------------------------------- kantong

const _emergencyWords = [
  'APOTEK',
  'APOTIK',
  'FARMA',
  'K-24',
  'KLINIK',
  'RUMAH SAKIT',
  'HOSPITAL',
  'DOKTER',
  'OBAT',
  'LAB ',
  'BENGKEL',
  'SERVIS',
  'SERVICE CENTER',
  'TAMBAL',
];

const _wantWords = [
  'CAFE',
  'KAFE',
  'COFFEE',
  'KOPI',
  'STARBUCKS',
  'JANJI JIWA',
  'KENANGAN',
  'CHATIME',
  'MIXUE',
  'BOBA',
  'KFC',
  'MCDONALD',
  'BURGER',
  'PIZZA',
  'RICHEESE',
  'GACOAN',
  'HOKBEN',
  'SOLARIA',
  'RESTO',
  'RESTAURANT',
  'BAKERY',
  'XXI',
  'CGV',
  'CINEMA',
  'BIOSKOP',
  'KARAOKE',
  'GAME',
  'STEAM',
  'NETFLIX',
  'SPOTIFY',
  'ZARA',
  'UNIQLO',
  'H&M',
  'SEPHORA',
  'WATSONS',
  'GUARDIAN',
  'GOFOOD',
  'GRABFOOD',
  'SHOPEEFOOD',
  'ICE CREAM',
  'ES KRIM',
  'SNACK',
];

/// Tebak tipe kantong dari nama toko & item. Bawaan: Wajib.
PocketType guessPocketType(ReceiptData receipt) {
  final text = _norm(
    [
      receipt.merchant ?? '',
      ...receipt.items.map((i) => i.name),
      receipt.text,
    ].join(' '),
  );
  if (_emergencyWords.any(text.contains)) return PocketType.darurat;
  if (_wantWords.any(text.contains)) return PocketType.keinginan;
  return PocketType.wajib;
}

/// Penjelasan tebakan, mis. "Wajib (kebutuhan pokok)".
String pocketGuessReason(PocketType type) => switch (type) {
  PocketType.wajib => 'kebutuhan pokok',
  PocketType.darurat => 'kesehatan & mendadak',
  PocketType.keinginan => 'jajan & hiburan',
};
