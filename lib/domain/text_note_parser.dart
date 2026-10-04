import 'receipt_parser.dart';
import 'types.dart';

/// Pengenal ketikan "kayak ngobrol" (layar 60–62), jalan di HP tanpa
/// internet. Contoh:
///   "tadi beli kopi susu 25rb sama bensin 30rb, terus Dimas bayar utang 150rb"
///   → Kopi susu -25.000 · Bensin -30.000 · Dimas bayar utang +150.000
///
/// Hanya paham catatan uang keluar & masuk. Teks lain → [TextNoteNotUnderstood].

enum NoteKind { expense, income }

class TextNote {
  const TextNote({
    required this.kind,
    required this.amount,
    required this.title,
    this.pocketType = PocketType.wajib,
  });

  final NoteKind kind;
  final int amount;
  final String title;

  /// Jenis kantong tebakan (hanya untuk uang keluar).
  final PocketType pocketType;

  bool get isIncome => kind == NoteKind.income;

  @override
  String toString() => '${isIncome ? '+' : '-'}$amount $title ($pocketType)';
}

sealed class TextNoteResult {
  const TextNoteResult();
}

/// Kebaca satu catatan atau lebih.
final class TextNotesRead extends TextNoteResult {
  const TextNotesRead(this.notes, {this.daysAgo = 0});

  final List<TextNote> notes;

  /// 0 = hari ini, 1 = kemarin, dst.
  final int daysAgo;
}

/// Soal uang tapi nominalnya tidak ada ("beli kopi").
final class TextNoteNeedsAmount extends TextNoteResult {
  const TextNoteNeedsAmount();
}

/// Bukan catatan uang ("besok hujan nggak ya?").
final class TextNoteNotUnderstood extends TextNoteResult {
  const TextNoteNotUnderstood();
}

const _maxAmount = 100000000000; // Rp 100 miliar

TextNoteResult parseTextNote(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return const TextNoteNotUnderstood();
  // Huruf kecil dengan panjang sama supaya posisi tetap cocok dengan teks asli
  // (judul diambil dari teks asli, mis. nama "Dimas" tetap kapital).
  final lowered = raw.toLowerCase();
  final orig = lowered.length == raw.length ? raw : lowered;
  var text = lowered.replaceAll(RegExp(r'[\r\n\t]'), ' ');

  if (text.contains('?') || _questionStart.hasMatch(text)) {
    return const TextNoteNotUnderstood();
  }

  // Hari: "kemarin", "2 hari lalu".
  var daysAgo = 0;
  final ago = RegExp(r'\b(\d) hari (yang |yg )?(lalu|kemarin)\b')
      .firstMatch(text);
  if (ago != null) {
    daysAgo = int.parse(ago[1]!);
  } else if (RegExp(r'\b(kemarin|kemaren|kmrn|kmarin) lusa\b').hasMatch(text)) {
    daysAgo = 2;
  } else if (RegExp(r'\b(kemarin|kemaren|kmrn|kmaren|kmarin)\b')
      .hasMatch(text)) {
    daysAgo = 1;
  }
  for (final re in _blankOut) {
    text = text.replaceAllMapped(re, (m) => ' ' * m[0]!.length);
  }

  final spans = _amountSpans(text);
  if (spans.isEmpty) {
    return _moneyWord.hasMatch(text)
        ? const TextNoteNeedsAmount()
        : const TextNoteNotUnderstood();
  }

  // Teks di antara nominal: s0 a1 s1 a2 s2 … an sn.
  final segs = <String>[
    for (var i = 0; i <= spans.length; i++)
      orig.substring(
        i == 0 ? 0 : spans[i - 1].end,
        i == spans.length ? orig.length : spans[i].start,
      ),
  ];
  // Bagian yang sudah dikosongkan (hari, cara bayar) juga dibuang dari judul.
  final masked = <String>[
    for (var i = 0; i <= spans.length; i++)
      text.substring(
        i == 0 ? 0 : spans[i - 1].end,
        i == spans.length ? text.length : spans[i].start,
      ),
  ];
  String keep(int i) {
    final b = StringBuffer();
    for (var k = 0; k < segs[i].length; k++) {
      b.write(masked[i][k] == ' ' ? ' ' : segs[i][k]);
    }
    return b.toString();
  }

  final cleaned = [for (var i = 0; i < segs.length; i++) _clean(keep(i))];
  final n = spans.length;
  final titles = <String>[];
  if (cleaned.first.isEmpty && cleaned.last.isNotEmpty) {
    // Nominal duluan: "25rb kopi, 30rb bensin".
    titles.addAll([
      for (final t in cleaned.sublist(1))
        t.replaceFirst(
          RegExp(r'^(buat|untuk|utk|bwt) +', caseSensitive: false),
          '',
        ),
    ]);
  } else {
    titles.addAll(cleaned.sublist(0, n));
    final tail = cleaned.last;
    if (tail.isNotEmpty) {
      final low = tail.toLowerCase();
      final last = titles[n - 1];
      final purpose = RegExp(r'^(buat|untuk|utk|bwt) +').firstMatch(low);
      if (RegExp(r'^(dari|ke) ').hasMatch(low)) {
        titles[n - 1] = last.isEmpty ? tail : '$last $tail';
      } else if (purpose != null) {
        final rest = tail.substring(purpose.end);
        final verb = last.toLowerCase();
        titles[n - 1] = verb == 'bayar'
            ? '$last $rest'
            : (last.isEmpty || _lonelyVerbs.contains(verb))
            ? rest
            : last;
      } else if (last.isEmpty) {
        titles[n - 1] = tail;
      }
    }
  }

  final notes = <TextNote>[];
  for (var i = 0; i < n && notes.length < 20; i++) {
    final title = titles[i];
    final kind = _kindOf(title.toLowerCase());
    final label = title.isEmpty
        ? (kind == NoteKind.income ? 'Pemasukan' : 'Pengeluaran')
        : title[0].toUpperCase() + title.substring(1);
    notes.add(
      TextNote(
        kind: kind,
        amount: spans[i].value,
        title: label,
        pocketType: kind == NoteKind.income
            ? PocketType.wajib
            : guessPocketType(ReceiptData(text: title)),
      ),
    );
  }
  return TextNotesRead(notes, daysAgo: daysAgo);
}

// ---------------------------------------------------------------- nominal

class _Span {
  const _Span(this.start, this.end, this.value);
  final int start;
  final int end;
  final int value;
}

final _numberRe = RegExp(
  r'(?<![\w.,])(rp\.?\s*)?(\d+(?:[.,]\d+)*)\s*(ribu|rb|k|juta|jt)?(?![\w])',
);

const _slang = {
  'seceng': 1000,
  'noceng': 2000,
  'goceng': 5000,
  'ceban': 10000,
  'noban': 20000,
  'goban': 50000,
  'gocap': 50000,
};

const _digitWords = {
  'satu': 1,
  'dua': 2,
  'tiga': 3,
  'empat': 4,
  'lima': 5,
  'enam': 6,
  'tujuh': 7,
  'delapan': 8,
  'sembilan': 9,
};
final _valueWords = {
  ..._digitWords.keys,
  'sepuluh',
  'sebelas',
  'seratus',
  'seribu',
  'sejuta',
  'setengah',
};
const _scaleWords = {'belas', 'puluh', 'ratus', 'ribu', 'rb', 'juta', 'jt'};

final _wordRunRe = RegExp(
  '\\b((?:${[..._valueWords, ..._scaleWords].join('|')})'
  '(?:\\s+(?:${[..._valueWords, ..._scaleWords].join('|')}))*)\\b',
);

List<_Span> _amountSpans(String text) {
  final spans = <_Span>[];
  for (final m in _numberRe.allMatches(text)) {
    final number = m[2]!;
    final suffix = m[3];
    final hasRp = m[1] != null;
    int? value;
    if (suffix == 'juta' || suffix == 'jt') {
      final d = double.tryParse(number.replaceAll(',', '.'));
      if (d != null) value = (d * 1000000).round();
    } else if (suffix != null) {
      final d = double.tryParse(number.replaceAll(',', '.'));
      if (d != null) value = (d * 1000).round();
    } else {
      value = int.tryParse(number.replaceAll(RegExp('[.,]'), ''));
      // Angka kecil tanpa rb/jt/Rp = jumlah barang ("2 kopi"), bukan nominal.
      if (value != null && value < 1000 && !hasRp) value = null;
    }
    if (value != null && value > 0 && value <= _maxAmount) {
      spans.add(_Span(m.start, m.end, value));
    }
  }
  for (final m in _wordRunRe.allMatches(text)) {
    final words = m[1]!.split(RegExp(r'\s+'));
    // Harus ada angka (bukan cuma "rb") dan skala besar ("ribu", "juta").
    if (!words.any(_valueWords.contains)) continue;
    if (!words.any(
      (w) => const {'ribu', 'rb', 'juta', 'jt', 'seribu', 'sejuta'}.contains(w),
    )) {
      continue;
    }
    final value = _wordsToNumber(words);
    if (value > 0 && value <= _maxAmount) {
      spans.add(_Span(m.start, m.end, value));
    }
  }
  for (final e in _slang.entries) {
    for (final m in RegExp('\\b${e.key}\\b').allMatches(text)) {
      spans.add(_Span(m.start, m.end, e.value));
    }
  }
  spans.sort((a, b) => a.start.compareTo(b.start));
  final out = <_Span>[];
  for (final s in spans) {
    if (out.isNotEmpty && s.start < out.last.end) continue;
    out.add(s);
  }
  return out;
}

int _wordsToNumber(List<String> words) {
  double total = 0, group = 0, unit = 0;
  for (final w in words) {
    if (_digitWords[w] case final d?) {
      unit = d.toDouble();
      continue;
    }
    switch (w) {
      case 'setengah':
        unit = unit > 0 ? unit + 0.5 : 0.5;
      case 'sepuluh':
        group += 10;
      case 'sebelas':
        group += 11;
      case 'seratus':
        group += 100;
      case 'seribu':
        total += 1000;
      case 'sejuta':
        total += 1000000;
      case 'belas':
        group += 10 + unit;
        unit = 0;
      case 'puluh':
        group += unit * 10;
        unit = 0;
      case 'ratus':
        group += unit * 100;
        unit = 0;
      case 'ribu' || 'rb':
        total += (group + unit == 0 ? 1 : group + unit) * 1000;
        group = unit = 0;
      case 'juta' || 'jt':
        total += (group + unit == 0 ? 1 : group + unit) * 1000000;
        group = unit = 0;
    }
  }
  return (total + group + unit).round();
}

// ------------------------------------------------------------------ judul

/// Bagian teks yang dibuang sebelum dibaca: kata hari & cara bayar.
final _blankOut = [
  RegExp(r'\b\d hari (yang |yg )?(lalu|kemarin)\b'),
  RegExp(r'\b(kemarin|kemaren|kmrn|kmaren|kmarin)( lusa)?\b'),
  RegExp(r'\bhari ini\b'),
  RegExp(r'\b(tadi|td) (pagi|siang|sore|malem|malam)\b'),
  RegExp(r'\b(pagi|siang|sore) (ini|tadi)\b'),
  RegExp(r'\bbarusan\b'),
  RegExp(
    r'\b(bayar |bayarnya )?(pake|pakai|pakek|via|lewat|pk)\s+'
    r'(gopay|ovo|dana|shopee ?pay|spay|qris|cash|tunai|debit|kartu kredit|'
    r'kartu debit|kartu|cc|transfer|tf|m-?banking|bca|bri|bni|mandiri|jago|'
    r'seabank|blu|livin|brimo|e-?wallet)\b',
  ),
  RegExp(r'\b(cash|tunai)\b'),
];

final _questionStart = RegExp(
  r'^\s*(apa|apakah|gimana|bagaimana|kenapa|mengapa|kapan|siapa|dimana|'
  r'di mana|kok|hai|halo|hello|hi|tolong|bisa)\b',
);

final _moneyWord = RegExp(
  r'\b(beli|bayar|jajan|makan|minum|ngopi|gaji|gajian|dapet|dapat|transfer|'
  r'tf|utang|hutang|belanja|isi|top ?up|bensin|parkir|ongkir|kopi|pulsa|kuota|'
  r'kos|kost|sewa|cicilan|tagihan|listrik|uang|duit|harga|rp|nonton|'
  r'langganan|jualan|jual|bonus|thr|pinjam|pinjem|traktir)\b',
);

const _leadFillers = {
  'dan',
  'sama',
  'sm',
  'terus',
  'trus',
  'trs',
  'lalu',
  'plus',
  'juga',
  'jg',
  'tadi',
  'td',
  'aku',
  'saya',
  'gue',
  'gw',
  'ak',
  'sy',
  'beli',
  'beliin',
  'abis',
  'habis',
  'itu',
  'yang',
  'yg',
  'kan',
  'nih',
  'hari',
  'ini',
};
const _tailFillers = {
  'seharga',
  'harga',
  'harganya',
  'sebesar',
  'senilai',
  'total',
  'totalnya',
  'rp',
  'sekitar',
  'kurleb',
  'cuma',
  'cuman',
  'doang',
  'aja',
  'kena',
  'abis',
  'habis',
  'sama',
  'dan',
  'terus',
  'trus',
  'yang',
  'yg',
  'tadi',
  'nih',
  'ya',
  'sih',
  'deh',
};
const _lonelyVerbs = {'beli', 'keluar', 'habis', 'abis', 'jajan', 'belanja'};

String _clean(String segment) {
  final words = segment
      .replaceAll(RegExp(r'''[,;:=+&()!."'*]|(?<!\w)-|-(?!\w)'''), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  while (words.isNotEmpty && _leadFillers.contains(words.first.toLowerCase())) {
    words.removeAt(0);
  }
  while (words.isNotEmpty && _tailFillers.contains(words.last.toLowerCase())) {
    words.removeLast();
  }
  return words.join(' ');
}

// ------------------------------------------------------------ masuk/keluar

final _expenseDebt = RegExp(
  r'\b(bayar (h?utang|cicilan) (ke|sama|sm)|nyicil (h?utang)|cicil (h?utang)|'
  r'minjemin|pinjemin|kasih (pinjam|pinjem)|ngasih (pinjam|pinjem)|'
  r'transfer ke|tf ke|kirim ke|ngirim ke|kirim (uang|duit) ke|bayarin|traktir|'
  r'bayar gaji|gaji (art|karyawan|pegawai)|nyumbang|sumbang|sedekah|infaq|'
  r'zakat|kasih (uang|duit)|ngasih (uang|duit))\b',
);
final _repay = RegExp(
  r'^(.*?)\b(bayar|balikin|lunasin|nyicil|cicil|ganti|kembaliin|ngembaliin)\s+'
  r'(h?utang|utangnya|hutangnya|duit|uang)',
);
const _selfWords = {
  'aku',
  'saya',
  'gue',
  'gw',
  'ak',
  'sy',
  'ku',
  'mau',
  'harus',
};
final _incomeWord = RegExp(
  r'\b(gaji|gajian|bonus|thr|dapet|dapat|dpt|terima|nerima|diterima|dikasih|'
  r'dikirim|dikirimin|ditransfer|transferan|(uang|duit|dana) masuk|cashback|'
  r'refund|komisi|honor|upah|jual|jualan|laku|untung|dibayar|dibayarin|dibalikin|'
  r'pinjam dari|pinjem dari|minjem dari|ngutang|uang jajan|angpao|angpau|'
  r'menang|cair|pencairan|freelance|orderan)\b',
);

NoteKind _kindOf(String clause) {
  if (_expenseDebt.hasMatch(clause)) return NoteKind.expense;
  final repay = _repay.firstMatch(clause);
  if (repay != null) {
    // "Dimas bayar utang" = uang masuk; "aku bayar utang" = keluar.
    final subject = repay[1]!.trim().split(RegExp(r'\s+'));
    final someoneElse =
        subject.first.isNotEmpty && !_selfWords.contains(subject.last);
    return someoneElse ? NoteKind.income : NoteKind.expense;
  }
  if (_incomeWord.hasMatch(clause)) return NoteKind.income;
  return NoteKind.expense;
}
