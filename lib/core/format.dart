import 'package:intl/intl.dart';

final _ribuan = NumberFormat.decimalPattern('id_ID');

/// 2180000 -> "Rp 2.180.000"
String rupiah(int value) => 'Rp ${_ribuan.format(value)}';

/// Pengeluaran: 52000 -> "-Rp 52.000"
String rupiahOut(int value) => '-${rupiah(value)}';

/// Versi singkat untuk tempat sempit: 450000 -> "Rp 450rb", 1300000 -> "Rp 1,3jt".
String rupiahShort(int value) {
  if (value < 0) return '-${rupiahShort(-value)}';
  if (value >= 1000000) {
    final jt = value / 1000000;
    final text = jt == jt.roundToDouble()
        ? jt.toStringAsFixed(0)
        : jt
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0$'), '')
              .replaceAll('.', ',');
    return 'Rp ${text}jt';
  }
  if (value >= 1000) return 'Rp ${(value / 1000).round()}rb';
  return 'Rp $value';
}

const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
const _monthsLong = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String dayName(DateTime d) => _days[d.weekday - 1];

/// "24 Sep"
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "Kamis, 24 Sep"
String dayTitle(DateTime d) => '${dayName(d)}, ${shortDate(d)}';

/// "Kamis, 24 Sep 2026"
String fullDate(DateTime d) => '${dayTitle(d)} ${d.year}';

/// "Sep 2026"
String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// "September 2026"
String monthYearLong(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

/// "09:05"
String clock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "Hari ini" / "Kemarin" / "24 Sep" relatif terhadap [today].
String relativeDay(DateTime d, DateTime today) {
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(today.year, today.month, today.day);
  final diff = (b.difference(a).inHours / 24).round();
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  return shortDate(d);
}
