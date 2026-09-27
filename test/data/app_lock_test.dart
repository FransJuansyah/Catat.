import 'package:catat/data/app_lock.dart';
import 'package:catat/domain/pin.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBio implements BiometricAuth {
  bool has = true;
  bool pass = true;

  @override
  Future<bool> available() async => has;

  @override
  Future<bool> authenticate() async => pass;
}

void main() {
  late MemoryLockStore store;
  late FakeBio bio;
  late DateTime now;

  AppLock lock() => AppLock(store, bio, () => now);

  setUp(() {
    store = MemoryLockStore();
    bio = FakeBio();
    now = DateTime(2026, 9, 27, 10);
  });

  test('belum ada PIN: tidak terkunci', () async {
    final l = lock();
    await l.load();
    expect(l.state.enabled, isFalse);
    expect(l.state.locked, isFalse);
  });

  test('PIN tidak disimpan sebagai angka asli', () async {
    await lock().setPin('482913');
    expect(store.values.values, isNot(contains('482913')));
    expect(store.values.keys, containsAll(['hash', 'salt']));
  });

  test('buka app lagi → terkunci, PIN benar membuka', () async {
    await lock().setPin('482913');
    final l = lock();
    await l.load();
    expect(l.state.locked, isTrue);
    expect(l.unlockWithPin('000000'), isFalse);
    expect(l.state.throttle.failures, 1);
    expect(l.unlockWithPin('482913'), isTrue);
    expect(l.state.locked, isFalse);
    expect(l.state.throttle.failures, 0);
  });

  test('5x salah → dijeda, PIN benar pun ditolak sampai jeda habis', () async {
    final l = lock();
    await l.setPin('482913');
    l.state = l.state.copyWith(locked: true);
    for (var i = 0; i < Pin.maxTries; i++) {
      l.unlockWithPin('111111');
    }
    expect(l.unlockWithPin('482913'), isFalse);
    now = now.add(const Duration(seconds: 31));
    expect(l.unlockWithPin('482913'), isTrue);
  });

  test('jeda kunci: 1 menit (default)', () async {
    final l = lock();
    await l.setPin('482913');
    l
      ..paused()
      ..resumed();
    expect(l.state.locked, isFalse); // balik cepat (mis. buka notif)
    l.paused();
    now = now.add(const Duration(minutes: 2));
    l.resumed();
    expect(l.state.locked, isTrue);
  });

  test('jeda "Langsung": tiap balik ke app terkunci', () async {
    final l = lock();
    await l.setPin('482913');
    await l.setDelay(LockDelay.now);
    l
      ..paused()
      ..resumed();
    expect(l.state.locked, isTrue);
  });

  test('sidik jari: harus lolos sekali dulu baru nyala', () async {
    final l = lock();
    await l.load();
    await l.setPin('482913');
    bio.pass = false;
    await l.setBiometric(true);
    expect(l.state.biometric, isFalse);
    bio.pass = true;
    await l.setBiometric(true);
    expect(l.state.biometric, isTrue);

    final again = lock();
    await again.load();
    expect(again.state.locked, isTrue);
    expect(await again.unlockWithBiometric(), isTrue);
    expect(again.state.locked, isFalse);
  });

  test('lupa PIN → dimatikan, PIN & sidik jari dihapus', () async {
    final l = lock();
    await l.setPin('482913');
    await l.setBiometric(true);
    await l.disable();
    expect(store.values.containsKey('hash'), isFalse);
    expect(l.state.enabled, isFalse);
    expect(l.state.biometric, isFalse);
  });
}
