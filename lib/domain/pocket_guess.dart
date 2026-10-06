import 'expense_icon.dart';
import 'home_summary.dart';
import 'types.dart';

/// Kata di nama kantong buatan user untuk tiap kategori pengeluaran
/// (kategori dari [guessExpenseIcon]).
const _nameWords = <String, List<String>>{
  'coffee': ['kopi', 'jajan', 'nongkrong', 'ngopi', 'cafe', 'healing'],
  'food': ['makan', 'jajan', 'dapur', 'konsumsi', 'kuliner', 'pangan'],
  'fuel': ['transport', 'bensin', 'kendaraan', 'motor', 'mobil', 'bbm'],
  'car': ['transport', 'ojek', 'kendaraan', 'perjalanan', 'motor', 'mobil'],
  'house': ['kos', 'rumah', 'sewa', 'tagihan', 'kontrakan'],
  'bolt': ['tagihan', 'listrik', 'rumah', 'kos'],
  'phone': ['pulsa', 'internet', 'kuota', 'tagihan', 'langganan'],
  'bag': ['belanja', 'dapur', 'bulanan', 'kebutuhan'],
  'heart': ['kesehatan', 'obat', 'sehat'],
  'film': ['hiburan', 'healing', 'nonton', 'hobi'],
  'shirt': ['baju', 'fashion', 'belanja'],
  'gift': ['hadiah', 'kado', 'sosial'],
};

/// Ikon kantong yang cocok dengan kategori pengeluaran.
const _iconFor = <String, List<String>>{
  'coffee': ['coffee'],
  'food': ['coffee', 'food'],
  'fuel': ['car', 'fuel', 'plane'],
  'car': ['car', 'fuel', 'plane'],
  'house': ['house'],
  'heart': ['heart', 'shield'],
  'film': ['film', 'gamepad', 'music', 'sparkles'],
  'shirt': ['shirt', 'bag'],
  'gift': ['gift'],
};

/// Kantong yang jelas bukan tempat jajan/belanja harian.
const _notForSpending = ['tabungan', 'nabung', 'investasi', 'simpanan'];

bool _nameHas(PocketView p, List<String> words) {
  final name = p.name.toLowerCase();
  return words.any(name.contains);
}

/// Tebak kantong untuk satu pengeluaran berjudul [title]:
/// 1. nama/ikon kantong cocok dengan kategori ("Bensin" → kantong Transport),
/// 2. jenis kantong ([type]) yang namanya tidak bertentangan,
/// 3. kantong Wajib, lalu kantong pertama.
PocketView? guessPocket(
  String title,
  PocketType type,
  List<PocketView> pockets,
) {
  if (pockets.isEmpty) return null;
  final category = guessExpenseIcon(title, fallback: '');
  if (category.isNotEmpty) {
    final words = _nameWords[category] ?? const [];
    final byName = pockets.where((p) => _nameHas(p, words)).firstOrNull;
    if (byName != null) return byName;
    final icons = _iconFor[category] ?? const [];
    final byIcon = pockets.where((p) => icons.contains(p.iconKey)).firstOrNull;
    if (byIcon != null) return byIcon;
  }
  // Kantong yang namanya untuk kategori lain ("Transport" untuk kopi) atau
  // untuk menabung tidak dipakai sebagai tebakan jenis.
  final otherCategories = {
    for (final e in _nameWords.entries)
      if (e.key != category) ...e.value,
  }..removeAll(_nameWords[category] ?? const []);
  bool conflicts(PocketView p) =>
      _nameHas(p, _notForSpending) ||
      (category.isNotEmpty && _nameHas(p, otherCategories.toList()));
  final byType = pockets
      .where((p) => p.type == type && !conflicts(p))
      .firstOrNull;
  if (byType != null) return byType;
  return pockets
          .where((p) => p.type == PocketType.wajib && !conflicts(p))
          .firstOrNull ??
      pockets.where((p) => !conflicts(p)).firstOrNull ??
      pockets.first;
}
