import 'dart:convert';

import 'package:crypto/crypto.dart';

/// PIN buka catat. (layar 56–58): 6 angka, disimpan sebagai hash + garam,
/// tidak pernah sebagai angka aslinya.
abstract final class Pin {
  static const length = 6;

  /// Salah berturut-turut sebanyak ini → tunggu [cooldown].
  static const maxTries = 5;
  static const cooldown = Duration(seconds: 30);

  /// Diulang supaya menebak 1 juta kemungkinan PIN dari hash curian lambat.
  static const _rounds = 20000;

  static String hash(String pin, String salt) {
    List<int> digest = utf8.encode('$salt:$pin');
    for (var i = 0; i < _rounds; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Encode(digest);
  }

  /// PIN yang gampang ditebak: angka sama semua (111111) atau urut naik /
  /// turun (123456, 987654). null = aman.
  static String? weakness(String pin) {
    if (pin.split('').toSet().length == 1) return 'Angkanya jangan sama semua';
    final d = pin.codeUnits;
    bool steps(int by) {
      for (var i = 1; i < d.length; i++) {
        if (d[i] - d[i - 1] != by) return false;
      }
      return true;
    }

    if (steps(1) || steps(-1)) return 'Jangan pakai angka urut';
    return null;
  }
}

/// Hitung salah PIN & jeda setelah terlalu sering salah.
class PinThrottle {
  const PinThrottle({this.failures = 0, this.waitUntil});

  final int failures;
  final DateTime? waitUntil;

  bool blocked(DateTime now) => waitUntil != null && now.isBefore(waitUntil!);

  /// Detik tersisa sebelum boleh coba lagi.
  int secondsLeft(DateTime now) =>
      blocked(now) ? waitUntil!.difference(now).inSeconds + 1 : 0;

  PinThrottle wrong(DateTime now) {
    final n = failures + 1;
    return n >= Pin.maxTries
        ? PinThrottle(failures: 0, waitUntil: now.add(Pin.cooldown))
        : PinThrottle(failures: n);
  }
}
