import 'dart:async';

import 'package:flutter/services.dart';

/// Status izin & pengingat (layar Privasi & Izin, Akun).
class DeviceStatus {
  const DeviceStatus({
    this.cameraGranted = false,
    this.canNotify = false,
    this.reminder = false,
    this.reminderHour = 21,
  });

  /// Izin kamera Android (scan struk).
  final bool cameraGranted;

  /// Boleh mengirim notifikasi (Android 13+ perlu izin).
  final bool canNotify;
  final bool reminder;
  final int reminderHour;

  factory DeviceStatus.fromMap(Map<Object?, Object?> m) => DeviceStatus(
    cameraGranted: m['cameraGranted'] == true,
    canNotify: m['canNotify'] == true,
    reminder: m['reminder'] == true,
    reminderHour: (m['reminderHour'] as int?) ?? 21,
  );
}

/// Aplikasi dibuka dari share gambar / pengingat.
sealed class LaunchAction {
  const LaunchAction();
}

/// Gambar dibagikan ke catat. (screenshot bukti transfer / foto struk).
class ShareLaunch extends LaunchAction {
  const ShareLaunch(this.imagePath);
  final String imagePath;
}

class ReminderLaunch extends LaunchAction {
  const ReminderLaunch();
}

/// Jembatan ke Android (MainActivity, channel id.catat.catat/device).
/// Di-override di test.
abstract class DeviceBridge {
  Future<DeviceStatus> status();
  Future<DeviceStatus> setReminder(bool on);

  /// Buka info aplikasi di Pengaturan (izin hanya bisa dicabut dari sana).
  Future<void> openAppSettings();

  /// Minta izin kirim notifikasi (Android 13+). true = diizinkan.
  Future<bool> requestNotifications();

  /// Minta izin kamera. true = diizinkan.
  Future<bool> requestCamera();

  /// Aksi pembukaan yang menunggu (sekali ambil).
  Future<LaunchAction?> takeLaunch();

  /// Ada aksi baru saat aplikasi sudah terbuka.
  Stream<void> get launches;
}

class ChannelDeviceBridge implements DeviceBridge {
  ChannelDeviceBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'launch') _launches.add(null);
    });
  }

  static const _channel = MethodChannel('id.catat.catat/device');
  final _launches = StreamController<void>.broadcast();

  Future<DeviceStatus> _status(String method, [Object? args]) async {
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>(method, args);
      return m == null ? const DeviceStatus() : DeviceStatus.fromMap(m);
    } on MissingPluginException {
      return const DeviceStatus(); // bukan Android
    }
  }

  @override
  Future<DeviceStatus> status() => _status('status');

  @override
  Future<DeviceStatus> setReminder(bool on) =>
      _status('setReminder', {'on': on});

  @override
  Future<void> openAppSettings() =>
      _channel.invokeMethod<void>('openAppSettings');

  @override
  Future<bool> requestNotifications() async =>
      await _channel.invokeMethod<bool>('requestNotifications') ?? false;

  @override
  Future<bool> requestCamera() async =>
      await _channel.invokeMethod<bool>('requestCamera') ?? false;

  @override
  Future<LaunchAction?> takeLaunch() async {
    final Map<Object?, Object?>? m;
    try {
      m = await _channel.invokeMapMethod<Object?, Object?>('takeLaunch');
    } on MissingPluginException {
      return null;
    }
    if (m == null) return null;
    return switch (m['type']) {
      'share' => ShareLaunch(m['path']! as String),
      'reminder' => const ReminderLaunch(),
      _ => null,
    };
  }

  @override
  Stream<void> get launches => _launches.stream;
}

/// Alamat layar untuk satu aksi pembukaan.
String launchLocation(LaunchAction action) => switch (action) {
  ShareLaunch() => '/baca-struk',
  ReminderLaunch() => '/catat-ketik',
};
