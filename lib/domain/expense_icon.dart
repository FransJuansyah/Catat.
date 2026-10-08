/// Menebak ikon kategori dari judul pengeluaran, mis. "Makan siang" → food.
/// Hanya untuk tampilan; kantong tetap dipilih user.
///
/// Urutan penting: kata yang lebih spesifik ("rumah sakit") dicek lebih dulu
/// daripada yang umum ("rumah"). Kata pendek diberi spasi agar cocok utuh
/// (" kos " tidak cocok dengan "kosmetik").
const _keywords = <(String, List<String>)>[
  (
    'coffee',
    [
      'kopi',
      'coffee',
      'kafe',
      'cafe',
      'boba',
      'janji jiwa',
      'kenangan',
      'starbucks',
      'chatime',
      'es teh',
    ],
  ),
  (
    'heart',
    [
      'obat',
      'dokter',
      'apotek',
      'klinik',
      'rumah sakit',
      'skincare',
      'salon',
      ' gym ',
      'vitamin',
    ],
  ),
  (
    'food',
    [
      'makan',
      'nasi',
      'ayam',
      'bakso',
      ' mie ',
      'soto',
      'warteg',
      'resto',
      'food',
      'sarapan',
      'lunch',
      'dinner',
      'geprek',
      'martabak',
      'pizza',
      'burger',
      'seblak',
      ' sate ',
      'padang',
      'jajan',
    ],
  ),
  (
    'bag',
    [
      'belanja',
      'indomaret',
      'alfamart',
      'alfamidi',
      'superindo',
      'hypermart',
      'market',
      'shopee',
      'tokopedia',
      'lazada',
    ],
  ),
  (
    'card',
    [
      'kartu kredit',
      ' cc ',
      'paylater',
      'kredivo',
      'akulaku',
      'cicilan',
      'angsuran',
      'kredit',
    ],
  ),
  (
    'receipt',
    [' bpjs ', 'asuransi', 'pajak', 'iuran', 'tagihan', ' pbb ', ' stnk '],
  ),
  (
    'banknote',
    ['tarik tunai', 'ambil uang', 'tarik uang', ' atm ', ' tunai ', ' cash '],
  ),
  ('bank', ['admin bank', 'biaya admin', 'biaya transfer', 'transfer bank']),
  ('bolt', ['listrik', 'token', ' pln ', 'pdam', ' air ', ' gas ']),
  ('fuel', ['bensin', 'pertalite', 'pertamax', 'spbu', ' bbm ']),
  (
    'train',
    ['kereta', ' krl ', ' mrt ', ' lrt ', 'commuter', 'kartu kereta', 'whoosh'],
  ),
  (
    'car',
    [
      'ojek',
      'gojek',
      ' grab ',
      'maxim',
      'taksi',
      'taxi',
      'parkir',
      ' tol ',
      'busway',
      'transjakarta',
      ' bus ',
    ],
  ),
  ('bike', ['servis motor', 'service motor', 'bengkel', 'ganti oli']),
  ('house', [' kos ', ' kost ', 'sewa', 'kontrakan', 'rumah']),
  ('phone', ['pulsa', 'kuota', 'paket data']),
  (
    'wifi',
    ['internet', 'wifi', 'indihome', 'biznet', 'first media', 'myrepublic'],
  ),
  ('grad', ['sekolah', 'kuliah', ' spp ', ' ukt ', 'kursus', ' les ']),
  (
    'tv',
    [
      'netflix',
      'spotify',
      'youtube premium',
      'langganan',
      'disney',
      'vidio',
      'prime video',
      'icloud',
    ],
  ),
  (
    'film',
    [
      'nonton',
      'bioskop',
      'youtube',
      ' game ',
      ' film ',
      ' xxi ',
      ' cgv ',
      'konser',
    ],
  ),
  ('shirt', ['baju', 'celana', 'sepatu', 'kaos', 'outfit', 'jaket', ' tas ']),
  ('gift', [' kado ', 'hadiah', ' gift ', 'traktir']),
];

String guessExpenseIcon(String title, {required String fallback}) {
  final t = ' ${title.toLowerCase()} ';
  for (final (icon, words) in _keywords) {
    if (words.any(t.contains)) return icon;
  }
  return fallback;
}
