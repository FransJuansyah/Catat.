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

// ------------------------------------------------------------- total

/// Kata kunci total, urut dari yang paling meyakinkan.
const _totalKeys = [
  'GRAND TOTAL',
  'TOTAL BAYAR',
  'TOTAL BELANJA',
  'TOTAL PEMBAYARAN',
  'TOTAL TAGIHAN',
  'TOTAL HARGA',
  'HARUS DIBAYAR',
  'JUMLAH BAYAR',
  'TOTAL',
  'JUMLAH',
  'TAGIHAN',
  'AMOUNT',
  'SUBTOTAL',
  'SUB TOTAL',
];

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
];

({int index, int amount, bool keyword})? _findTotal(List<String> rows) {
  for (final key in _totalKeys) {
    for (var i = 0; i < rows.length; i++) {
      final r = _norm(rows[i]);
      if (!r.contains(key)) continue;
      if (key == 'TOTAL' &&
          (r.contains('SUBTOTAL') || r.contains('SUB TOTAL'))) {
        continue;
      }
      if (_notTotal.any(r.contains)) continue;
      final here = amountsIn(rows[i]);
      if (here.isNotEmpty) return (index: i, amount: here.last, keyword: true);
      // Harga kebaca di baris berikutnya (kolom kanan terpisah).
      if (i + 1 < rows.length && !_hasLetters(rows[i + 1])) {
        final next = amountsIn(rows[i + 1]);
        if (next.isNotEmpty) {
          return (index: i, amount: next.first, keyword: true);
        }
      }
    }
  }
  return null;
}

// ------------------------------------------------------------- item

final _qtyRe = RegExp(
  r'(?:\b[xX]\s?(\d{1,2})\b|\b(\d{1,2})\s?[xX]\b|\b(\d{1,2})\s?(?:PCS|pcs|Pcs|BH|bh)\b)',
);

String _cleanName(String s) {
  final name = s
      .replaceAll(_qtyRe, ' ')
      .replaceAll(RegExp(r'[@:]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return _titleCase(name);
}

/// Satu baris item: nama di kiri, harga total paling kanan.
ReceiptItem? _parseItem(String row) {
  final upper = _norm(row);
  if (_notItem.any(upper.contains)) return null;
  final amounts = amountsIn(row);
  if (amounts.isEmpty) return null;
  // Bagian nama = sebelum angka pertama yang bukan bagian nama (mis. "1L").
  final firstNum = RegExp(r'\s{2,}|\s(?=\d[\d.,]*\s|\d[\d.,]*$)')
      .firstMatch(row);
  final namePart = firstNum == null ? row : row.substring(0, firstNum.start);
  if (!_hasLetters(namePart)) return null;

  final price = amounts.last;
  var qty = 1;
  final q = _qtyRe.firstMatch(row);
  if (q != null) {
    qty = int.parse(q.group(1) ?? q.group(2) ?? q.group(3)!);
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
        amounts.isEmpty && _hasLetters(row) && !_notItem.any(upper.contains)
        ? row
        : null;
  }
  return items;
}

// ------------------------------------------------------------- toko

/// Nama toko/aplikasi yang sering muncul → ejaan rapi.
const _brands = {
  'INDOMARET': 'Indomaret',
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

String? _findMerchant(List<String> rows) {
  String? wallet;
  for (final row in rows.take(8).map(_norm)) {
    final brand = _brandIn(row);
    if (brand == null) continue;
    if (!_wallets.contains(brand)) return brand;
    wallet ??= brand;
  }
  final limit = wallet == null ? 5 : 8;
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
    final name = _titleCase(row.replaceAll(RegExp(r'\s{2,}'), ' ').trim());
    return name.length > 30 ? name.substring(0, 30).trim() : name;
  }
  return wallet;
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

DateTime? _findDate(List<String> rows, DateTime now) {
  final text = rows.join('\n');
  int year(String y) => y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
  DateTime? day;

  final ymd = RegExp(r'\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b')
      .firstMatch(text);
  final dmy = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b')
      .firstMatch(text);
  final named = RegExp(
    r'\b(\d{1,2})\s*[-\s]?\s*(JAN|FEB|MAR|APR|MEI|MAY|JUN|JUL|AGU|AGT|AUG|SEP|OKT|OCT|NOV|DES|DEC)[A-Z]*\.?\s*[-\s]?\s*(\d{2,4})\b',
    caseSensitive: false,
  ).firstMatch(text);
  RegExpMatch? found;
  if (ymd != null) {
    found = ymd;
    day = _safeDate(year(ymd[1]!), int.parse(ymd[2]!), int.parse(ymd[3]!));
  } else if (dmy != null) {
    found = dmy;
    day = _safeDate(year(dmy[3]!), int.parse(dmy[2]!), int.parse(dmy[1]!));
  } else if (named != null) {
    found = named;
    day = _safeDate(
      year(named[3]!),
      _monthNames[named[2]!.toUpperCase().substring(0, 3)]!,
      int.parse(named[1]!),
    );
  }
  if (day == null) return null;
  // Struk dari masa depan / lebih dari setahun lalu = salah baca.
  if (day.isAfter(now) && day.difference(now).inDays >= 1) return null;
  if (now.difference(day).inDays > 400) return null;

  // Jam hanya dari baris tanggal (atau baris sesudahnya): jam lain di foto
  // bisa menyesatkan, mis. jam status bar pada screenshot. Tidak ada → 12:00.
  final timeRe = RegExp(r'\b(\d{1,2}):(\d{2})(?::\d{2})?\b');
  final lineStart = text.lastIndexOf('\n', found!.start) + 1;
  var lineEnd = text.indexOf('\n', found.end);
  if (lineEnd >= 0) {
    final next = text.indexOf('\n', lineEnd + 1);
    lineEnd = next < 0 ? text.length : next;
  } else {
    lineEnd = text.length;
  }
  final time = timeRe.firstMatch(text.substring(lineStart, lineEnd));
  if (time != null) {
    final h = int.parse(time[1]!);
    final m = int.parse(time[2]!);
    if (h < 24 && m < 60) return DateTime(day.year, day.month, day.day, h, m);
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
ReceiptData parseReceipt(List<String> rows, {required DateTime now}) {
  final total = _findTotal(rows);
  final end = total?.index ?? rows.length;
  final items = _findItems(rows, end);
  final itemsSum = items.fold<int>(0, (s, i) => s + i.price);

  int? amount = total?.amount;
  if (amount == null && itemsSum > 0) amount = itemsSum;
  if (amount == null) {
    // Terakhir: nominal terbesar, kecuali baris uang tunai/kembalian.
    final candidates = [
      for (final r in rows)
        if (!_notTotal.any(_norm(r).contains)) ...amountsIn(r),
    ];
    if (candidates.isNotEmpty) amount = candidates.reduce(math.max);
  }

  return ReceiptData(
    merchant: _findMerchant(rows),
    date: _findDate(rows, now),
    total: amount,
    // Item yang jumlahnya melebihi total = salah baca → jangan ditampilkan.
    items: amount != null && itemsSum > amount * 1.5 ? const [] : items,
    totalFromKeyword: total?.keyword ?? false,
    text: rows.join('\n'),
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
