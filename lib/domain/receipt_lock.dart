import 'receipt_parser.dart';

/// Scan otomatis (layar 04 → 46): struk dianggap "kebaca" kalau baris TOTAL
/// kebaca dengan nominal yang sama di beberapa frame kamera berturut-turut.
/// Satu frame saja belum cukup: teks goyang sering salah baca angka.
class ReceiptLock {
  ReceiptLock({this.framesNeeded = 2});

  final int framesNeeded;

  int? _total;
  int _streak = 0;

  bool get locked => _streak >= framesNeeded;

  /// Masukkan hasil baca satu frame. `true` = struk kebaca & siap difoto.
  bool add(ReceiptData frame) {
    if (locked) return true;
    final total = frame.totalFromKeyword ? frame.total : null;
    if (total == null || total <= 0) {
      _total = null;
      _streak = 0;
    } else if (total == _total) {
      _streak++;
    } else {
      _total = total;
      _streak = 1;
    }
    return locked;
  }

  void reset() {
    _total = null;
    _streak = 0;
  }
}
