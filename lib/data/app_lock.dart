import 'dart:async';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/pin.dart';

/// Penyimpanan pengaturan kunci (hanya di HP ini, tidak ikut sinkron).
/// Di-override di test.
abstract class LockStore {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String? value);
}

/// Android Keystore lewat flutter_secure_storage.
class SecureLockStore implements LockStore {
  static const _storage = FlutterSecureStorage();
  static const _prefix = 'lock.';

  @override
  Future<Map<String, String>> readAll() async {
    final all = await _storage.readAll();
    return {
      for (final e in all.entries)
        if (e.key.startsWith(_prefix)) e.key.substring(_prefix.length): e.value,
    };
  }

  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: '$_prefix$key')
      : _storage.write(key: '$_prefix$key', value: value);
}

/// Sidik jari / wajah HP. Di-override di test.
abstract class BiometricAuth {
  Future<bool> available();
  Future<bool> authenticate();
}

class DeviceBiometricAuth implements BiometricAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> available() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Buka catat.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}

/// Jeda kunci setelah keluar dari app (layar 56).
enum LockDelay {
  now(Duration.zero, 'Langsung'),
  oneMinute(Duration(minutes: 1), '1 menit'),
  fiveMinutes(Duration(minutes: 5), '5 menit');

  const LockDelay(this.duration, this.label);

  final Duration duration;
  final String label;
}

class AppLockState {
  const AppLockState({
    this.loaded = false,
    this.enabled = false,
    this.biometric = false,
    this.biometricAvailable = false,
    this.delay = LockDelay.oneMinute,
    this.locked = false,
    this.throttle = const PinThrottle(),
  });

  final bool loaded;

  /// PIN sudah dibuat & kunci aktif.
  final bool enabled;
  final bool biometric;
  final bool biometricAvailable;
  final LockDelay delay;

  /// Layar 58 sedang menutupi app.
  final bool locked;
  final PinThrottle throttle;

  AppLockState copyWith({
    bool? loaded,
    bool? enabled,
    bool? biometric,
    bool? biometricAvailable,
    LockDelay? delay,
    bool? locked,
    PinThrottle? throttle,
  }) => AppLockState(
    loaded: loaded ?? this.loaded,
    enabled: enabled ?? this.enabled,
    biometric: biometric ?? this.biometric,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    delay: delay ?? this.delay,
    locked: locked ?? this.locked,
    throttle: throttle ?? this.throttle,
  );
}

/// Logika kunci app tanpa Riverpod (dites langsung).
class AppLock {
  AppLock(this._store, this._bio, this._now);

  final LockStore _store;
  final BiometricAuth _bio;
  final DateTime Function() _now;

  String? _hash;
  String? _salt;
  DateTime? _leftAt;

  AppLockState state = const AppLockState();
  final _changes = StreamController<AppLockState>.broadcast();
  Stream<AppLockState> get changes => _changes.stream;

  void _set(AppLockState s) {
    state = s;
    _changes.add(s);
  }

  /// Baca pengaturan; kunci aktif → app mulai terkunci.
  Future<void> load() async {
    final v = await _store.readAll();
    _hash = v['hash'];
    _salt = v['salt'];
    final enabled = _hash != null && _salt != null;
    _set(
      state.copyWith(
        loaded: true,
        enabled: enabled,
        biometric: v['biometric'] == '1',
        biometricAvailable: await _bio.available(),
        delay: LockDelay.values.firstWhere(
          (d) => d.name == v['delay'],
          orElse: () => LockDelay.oneMinute,
        ),
        locked: enabled,
      ),
    );
  }

  /// Bikin / ganti PIN (layar 57).
  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = List.generate(
      16,
      (_) => rnd.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _salt = salt;
    _hash = Pin.hash(pin, salt);
    await _store.write('salt', salt);
    await _store.write('hash', _hash);
    _set(state.copyWith(enabled: true, locked: false));
  }

  /// Matikan kunci (juga setelah "Lupa PIN" diverifikasi lewat email).
  Future<void> disable() async {
    _hash = null;
    _salt = null;
    await _store.write('hash', null);
    await _store.write('salt', null);
    await _store.write('biometric', null);
    _set(
      state.copyWith(
        enabled: false,
        biometric: false,
        locked: false,
        throttle: const PinThrottle(),
      ),
    );
  }

  Future<void> setBiometric(bool on) async {
    // Nyalakan hanya kalau sidik jari benar-benar lolos sekali.
    if (on && !await _bio.authenticate()) return;
    await _store.write('biometric', on ? '1' : null);
    _set(state.copyWith(biometric: on));
  }

  Future<void> setDelay(LockDelay delay) async {
    await _store.write('delay', delay.name);
    _set(state.copyWith(delay: delay));
  }

  /// PIN di layar 58. false = salah / sedang dijeda.
  bool unlockWithPin(String pin) {
    final now = _now();
    if (state.throttle.blocked(now)) return false;
    if (_hash != null && _salt != null && Pin.hash(pin, _salt!) == _hash) {
      _set(state.copyWith(locked: false, throttle: const PinThrottle()));
      return true;
    }
    _set(state.copyWith(throttle: state.throttle.wrong(now)));
    return false;
  }

  /// Cocokkan PIN lama (ganti PIN) tanpa mengubah status kunci.
  bool checkPin(String pin) =>
      _hash != null && _salt != null && Pin.hash(pin, _salt!) == _hash;

  Future<bool> unlockWithBiometric() async {
    if (!state.biometric || !state.locked) return false;
    if (!await _bio.authenticate()) return false;
    _set(state.copyWith(locked: false, throttle: const PinThrottle()));
    return true;
  }

  /// App ke latar belakang.
  void paused() => _leftAt ??= _now();

  /// App kembali: sudah lewat jeda → kunci.
  void resumed() {
    final left = _leftAt;
    _leftAt = null;
    if (!state.enabled || state.locked || left == null) return;
    if (_now().difference(left) >= state.delay.duration) {
      _set(state.copyWith(locked: true));
    }
  }

  void dispose() => _changes.close();
}

/// Penyimpanan di memori (test & build tanpa Keystore).
class MemoryLockStore implements LockStore {
  final values = <String, String>{};

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
}
