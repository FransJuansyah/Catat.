import 'receipt_parser.dart';
import 'types.dart';

/// Arah uang di notifikasi bank / e-wallet.
enum MoneyDirection { out, into }

/// Aplikasi bank / e-wallet yang notifikasinya dibaca (paket → nama tampil).
/// Daftar yang sama ada di CatatNotificationListener.kt.
const financeApps = {
  'com.gojek.app': 'GoPay',
  'com.gojek.gopay': 'GoPay',
  'id.dana': 'DANA',
  'ovo.id': 'OVO',
  'com.shopee.id': 'ShopeePay',
  'com.bca': 'BCA',
  'com.bca.mybca.omni.android': 'myBCA',
  'id.bmri.livin': "Livin'",
  'id.co.bri.brimo': 'BRImo',
  'id.bni.wondr': 'BNI',
  'src.com.bni': 'BNI',
  'com.bsm.activity2': 'BSI',
  'com.jago.digitalBanking': 'Jago',
  'id.co.bankbkemobile.digitalbank': 'SeaBank',
  'com.bcadigital.blu': 'blu',
  'com.btpn.dc': 'Jenius',
  'com.telkom.mwallet': 'LinkAja',
};

/// Dari mana notifikasi datang. Aplikasi chat (WhatsApp, Telegram, dll.)
/// sengaja tidak pernah dibaca.
enum NotificationSource {
  /// Aplikasi m-banking / e-wallet di [financeApps].
  financeApp,

  /// Aplikasi Pesan/SMS (SMS notifikasi bank).
  sms,

  /// Aplikasi email (email notifikasi bank).
  email,
}

/// Nama bank / e-wallet yang dicari di SMS & email (pola → nama tampil).
/// SMS/email yang tidak menyebut salah satunya diabaikan.
final _bankNames = <(RegExp, String)>[
  for (final (pattern, name) in const [
    (r'brimo|bank rakyat|\bbri\b', 'BRI'),
    (r'\bbca\b|mybca|klikbca', 'BCA'),
    (r'wondr|\bbni\b', 'BNI'),
    (r"livin'?|mandiri", 'Mandiri'),
    (r'\bbsi\b|bank syariah indonesia', 'BSI'),
    (r'\bbtn\b', 'BTN'),
    (r'cimb|octo', 'CIMB Niaga'),
    (r'permata', 'Permata'),
    (r'danamon', 'Danamon'),
    (r'\bocbc\b', 'OCBC'),
    (r'maybank', 'Maybank'),
    (r'\bbjb\b', 'bjb'),
    (r'\bjago\b', 'Jago'),
    (r'seabank', 'SeaBank'),
    (r'jenius|\bbtpn\b', 'Jenius'),
    (r'\bblu\b', 'blu'),
    (r'gopay', 'GoPay'),
    (r'\bovo\b', 'OVO'),
    (r'shopeepay', 'ShopeePay'),
    (r'linkaja', 'LinkAja'),
  ])
    (RegExp(pattern, caseSensitive: false), name),
  // "dana" juga kata biasa ("dana instan", "dana masuk") → hanya huruf kapital.
  (RegExp(r'\bDANA\b'), 'DANA'),
];

/// Nama bank / e-wallet yang disebut di [text].
String? bankNameIn(String text) {
  for (final (re, name) in _bankNames) {
    if (re.hasMatch(text)) return name;
  }
  return null;
}

// "BRI: Dana masuk …" / "BCA - Transaksi …" (SMS dari nomor pendek).
final _senderPrefixRe = RegExp(r"^\s*([A-Za-z' ]{2,24}?)\s*[:：\-]");

/// Bank pengirim SMS / email: dari nama pengirim, atau awalan isi pesan.
/// Nama bank yang cuma disebut di tengah pesan (iklan) tidak dihitung.
String? bankSender(String sender, String body) {
  final fromSender = bankNameIn(sender);
  if (fromSender != null) return fromSender;
  final prefix = _senderPrefixRe.firstMatch(body)?.group(1);
  return prefix == null ? null : bankNameIn(prefix);
}

/// Satu transaksi yang terbaca dari notifikasi.
class DetectedTransaction {
  const DetectedTransaction({
    required this.direction,
    required this.amount,
    required this.appName,
    required this.occurredAt,
    this.counterparty,
  });

  final MoneyDirection direction;
  final int amount;

  /// "GoPay", "BNI", …
  final String appName;

  /// Toko / nama orang ("Kopi Kenangan", "Budi Santoso"), bila terbaca.
  final String? counterparty;
  final DateTime occurredAt;

  /// Judul catatan: nama toko/orang, atau nama aplikasinya.
  String get title => counterparty ?? appName;

  /// Tebakan kantong untuk pengeluaran (pakai kata kunci parser struk).
  PocketType get pocketGuess =>
      guessPocketType(ReceiptData(merchant: counterparty, text: title));
}

// Bukan transaksi, atau pindah uang antar dompet sendiri (top up) yang akan
// dobel dengan notifikasi di sisi lain.
final _skipRe = RegExp(
  r'\b(otp|kode (?:verifikasi|otp|rahasia|aktivasi)|verification code|'
  r'jangan (?:berikan|bagikan)|promo|diskon|voucher|cashback s\.?d|hemat|'
  r'gratis|undian|top ?up|topup|isi saldo|gagal|dibatalkan|batal|tertunda|'
  r'pending|ditolak|kedaluwarsa|expired|jatuh tempo|jth tempo|denda|'
  r'mengingatkan|pinjaman)\b',
  caseSensitive: false,
);

// Iklan bank / pinjol / paylater (dari contoh SMS asli): link, ajakan,
// "s.d", bunga, cicilan, bonus, dll. Notifikasi transaksi tidak memuat ini.
final _adRe = RegExp(
  r'https?://|\b[a-z0-9-]+\.(?:id|com|co|link|ink|ly|app|mobi|me)/[^\s]*|'
  r'\b(?:kirim stop|penawaran|s\.\s?d\b|s/d|bonus|cicilan|bunga|tenor|'
  r'pay ?later|pinjam\w*|apply|daftar|ajukan|klik|referral|poin|hadiah|'
  r'dapatkan|nikmati|yuk)\b',
  caseSensitive: false,
);

final _inRe = RegExp(
  r'\b(masuk|menerima|diterima|terima|dapet|dapat transfer|kredit|credit|'
  r'refund|pengembalian dana|dana kembali|received|incoming)\b',
  caseSensitive: false,
);

final _outRe = RegExp(
  r'\b(keluar|bayar|dibayar|pembayaran|membayar|transfer ke|kirim|dikirim|'
  r'debit|debet|tarik tunai|penarikan|pembelian|belanja|qris|payment|paid|sent|'
  r'outgoing|purchase)\b',
  caseSensitive: false,
);

// "Rp50.000", "IDR 50,000.00", "Rp50rb", "Rp1,2jt".
final _rpRe = RegExp(
  r'(Rp|IDR)\.?\s*(\d[\d.,]*)\s*(rb|ribu|k|jt|juta)?\b',
  caseSensitive: false,
);

// Nominal setelah kata-kata ini bukan nominal transaksi.
final _notTxAmount = RegExp(
  r'(saldo(?: akhir| efektif)?|sisa(?: saldo)?|limit|balance|total saldo)\W*$',
  caseSensitive: false,
);

int? _amountWithUnit(String digits, String? unit) {
  final u = unit?.toLowerCase();
  if (u == null) return parseAmount(digits);
  // "1,2jt" / "1.5 juta" / "50rb": desimal pakai koma atau titik.
  final value = double.tryParse(digits.replaceAll(',', '.'));
  if (value == null) return null;
  final factor = (u == 'jt' || u == 'juta') ? 1000000 : 1000;
  return (value * factor).round();
}

final _counterpartyRe = RegExp(
  r'\b(?:ke|kepada|di|dari|to|from|at)\s+'
  r"([A-Za-z0-9][A-Za-z0-9 &'.\-*]{1,40}?)"
  r'(?=\s*(?:[,.!:;]\s|[,.!:;]?$|\s(?:pakai|via|pake|dengan|sebesar|senilai|'
  r'berhasil|sukses|telah|sudah|udah|pada|tgl|tanggal|jam|using|with|on|'
  r'was|is|has|ke|kepada|untuk|buat|rp|idr|saldo)\b|'
  // "Trf ke ANDI WIJAYA 26/09 10:00" (SMS bank): tanggal setelah nama.
  r'\s\d{1,2}[/.\-]\d{1,2}\b))',
  caseSensitive: false,
);

/// Nominal transaksi pertama ("Rp50.000", "Rp 50.000,00", "IDR 50,000"),
/// melewati nominal saldo.
int? _transactionAmount(String text) {
  for (final m in _rpRe.allMatches(text)) {
    final before = text.substring(0, m.start);
    if (_notTxAmount.hasMatch(before)) continue;
    final v = _amountWithUnit(m.group(2)!, m.group(3));
    if (v != null && v > 0) return v;
  }
  return null;
}

// "18/06/2025 07:39", "26-09-26 11.30" di isi SMS / email bank.
final _txTimeRe = RegExp(
  r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4}|\d{2})\s+(\d{1,2})[:.](\d{2})\b',
);

/// Waktu transaksi di isi pesan (SMS & email bisa telat s.d. 48 jam).
/// Dipakai kalau masuk akal: tidak di masa depan & paling lama 7 hari
/// sebelum pesan diterima. Selain itu: waktu pesan diterima.
DateTime _transactionTime(String text, DateTime postedAt) {
  final m = _txTimeRe.firstMatch(text);
  if (m == null) return postedAt;
  final [d, mo, y, h, mi] = [
    for (var i = 1; i <= 5; i++) int.parse(m.group(i)!),
  ];
  final year = y < 100 ? 2000 + y : y;
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) {
    return postedAt;
  }
  final at = DateTime(year, mo, d, h, mi);
  if (at.month != mo) return postedAt; // 31/02 dsb.
  final early = postedAt.subtract(const Duration(days: 7));
  final late = postedAt.add(const Duration(minutes: 5));
  return at.isBefore(early) || at.isAfter(late) ? postedAt : at;
}

String? _counterparty(String text, MoneyDirection direction, String appName) {
  // Uang keluar: "ke X" / "di X"; uang masuk: "dari X".
  for (final m in _counterpartyRe.allMatches(text)) {
    final word = text
        .substring(m.start, m.start + m.group(0)!.indexOf(' '))
        .toLowerCase();
    final isFrom = word == 'dari' || word == 'from';
    if (direction == MoneyDirection.into ? !isFrom : isFrom) continue;
    var name = m.group(1)!.trim();
    name = name.replaceAll(RegExp(r'[\s.\-*]+$'), '');
    if (name.length < 2) continue;
    // Nama rekening / nomor bukan nama toko.
    if (RegExp(r'^[\d\s*xX\-]+$').hasMatch(name)) continue;
    final lower = name.toLowerCase();
    if (lower == appName.toLowerCase() ||
        lower.startsWith('rekening') ||
        lower.startsWith('aplikasi') ||
        lower.startsWith('akun') ||
        lower.startsWith('saldo')) {
      continue;
    }
    return _tidy(name);
  }
  return null;
}

/// "KOPI KENANGAN" → "Kopi Kenangan"; campuran huruf dibiarkan.
String _tidy(String s) {
  if (s != s.toUpperCase()) return s;
  return s
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Baca satu notifikasi. null = bukan transaksi (OTP, promo, top up, dll.),
/// bukan dari aplikasi keuangan yang dikenal, atau SMS/email yang tidak
/// menyebut bank / e-wallet.
DetectedTransaction? parseBankNotification({
  required String packageName,
  required String title,
  required String text,
  required DateTime postedAt,
  NotificationSource source = NotificationSource.financeApp,
}) {
  final appName = switch (source) {
    NotificationSource.financeApp => financeApps[packageName],
    // Pengirim (judul) dulu: "BCA", "Livin' by Mandiri".
    _ => bankSender(title, text),
  };
  if (appName == null) return null;
  final all = '$title. $text'.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (_skipRe.hasMatch(all) || _adRe.hasMatch(all)) return null;

  final amount = _transactionAmount(all);
  if (amount == null) return null;

  final inHits = _inRe.allMatches(all).length;
  final outHits = _outRe.allMatches(all).length;
  // Judul biasanya paling jelas ("Uang Masuk", "Transaksi Keluar").
  final titleIn = _inRe.hasMatch(title);
  final titleOut = _outRe.hasMatch(title);
  final MoneyDirection direction;
  if (titleIn != titleOut) {
    direction = titleIn ? MoneyDirection.into : MoneyDirection.out;
  } else if (inHits != outHits) {
    direction = inHits > outHits ? MoneyDirection.into : MoneyDirection.out;
  } else {
    return null; // tidak jelas, lebih baik tidak menebak
  }

  final counterparty = _counterparty(all, direction, appName);
  if (_isOwnTransfer(all, direction, counterparty)) return null;

  return DetectedTransaction(
    direction: direction,
    amount: amount,
    appName: appName,
    occurredAt: _transactionTime(all, postedAt),
    counterparty: counterparty,
  );
}

// "Transfer ke GOPAY 0812…", "Trf ke OVO …": isi saldo e-wallet sendiri.
// DANA hanya huruf kapital ("ke dana darurat" bukan e-wallet).
final _toWalletRe = RegExp(
  r'\b(?:ke|kepada|to)\s+(?:akun\s+|e-?wallet\s+)?'
  r'(?:go-?pay|ovo|shopee ?pay|linkaja)\b',
  caseSensitive: false,
);
final _toDanaRe = RegExp(r'\b(?:ke|kepada|to)\s+(?:akun\s+)?DANA\b');

// Nama bank / e-wallet & kata rekening: kalau "dari X" isinya cuma ini,
// uangnya dari rekening / dompet sendiri (bukan dari orang atau kantor).
final _ownAccountWords = RegExp(
  r"brimo|bank rakyat|\bbri\b|\bbca\b|mybca|klikbca|wondr|\bbni\b|livin'?|"
  r'mandiri|\bbsi\b|\bbtn\b|cimb|octo|permata|danamon|\bocbc\b|maybank|'
  r'\bbjb\b|\bjago\b|seabank|jenius|\bbtpn\b|\bblu\b|go-?pay|\bovo\b|'
  r'shopee ?pay|linkaja|\bdana\b|virtual account|\bva\b|mobile|m-?banking|'
  r'rekening|\bbank\b|[\s\-*.&]',
  caseSensitive: false,
);

/// Pindah uang antar rekening / e-wallet sendiri (isi saldo GoPay dari BCA,
/// tarik DANA ke BRI). Saldo total tidak berubah: bukan pengeluaran maupun
/// pemasukan, dan sisi satunya sering ikut kirim notifikasi (dobel).
/// Transfer ke / dari orang lain tetap dicatat.
bool _isOwnTransfer(String all, MoneyDirection direction, String? from) {
  if (direction == MoneyDirection.out) {
    return _toWalletRe.hasMatch(all) || _toDanaRe.hasMatch(all);
  }
  if (from == null) return false;
  return from.replaceAll(_ownAccountWords, '').isEmpty;
}
