import 'package:intl/intl.dart';

final _ribuan = NumberFormat.decimalPattern('id_ID');

/// 2180000 -> "Rp 2.180.000"
String rupiah(int value) => 'Rp ${_ribuan.format(value)}';

/// Versi singkat untuk tempat sempit: 450000 -> "Rp 450rb", 1300000 -> "Rp 1,3jt".
String rupiahShort(int value) {
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
