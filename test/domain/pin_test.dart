import 'package:catat/domain/pin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hash: sama kalau PIN & garam sama, beda kalau garam beda', () {
    expect(Pin.hash('482913', 'a'), Pin.hash('482913', 'a'));
    expect(Pin.hash('482913', 'a'), isNot(Pin.hash('482913', 'b')));
    expect(Pin.hash('482913', 'a'), isNot(contains('482913')));
  });

  test('PIN gampang ditebak ditolak', () {
    expect(Pin.weakness('111111'), isNotNull);
    expect(Pin.weakness('123456'), isNotNull);
    expect(Pin.weakness('987654'), isNotNull);
    expect(Pin.weakness('482913'), isNull);
    expect(Pin.weakness('112233'), isNull);
  });

  test('5x salah → tunggu 30 detik, lalu boleh coba lagi', () {
    final now = DateTime(2026, 9, 27, 10);
    var t = const PinThrottle();
    for (var i = 0; i < 4; i++) {
      t = t.wrong(now);
      expect(t.blocked(now), isFalse);
    }
    t = t.wrong(now);
    expect(t.blocked(now), isTrue);
    expect(t.secondsLeft(now), 31);
    expect(t.blocked(now.add(const Duration(seconds: 31))), isFalse);
    expect(t.failures, 0);
  });
}
