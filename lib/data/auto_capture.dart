import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/bank_notification_parser.dart';

/// Status catat otomatis & pengingat (layar Akun).
class AutoStatus {
  const AutoStatus({
    this.enabled = false,
    this.listenerAccess = false,
    this.canNotify = false,
    this.reminder = false,
    this.reminderHour = 21,
  });

  /// User menyalakan "Catat otomatis" di Akun.
  final bool enabled;

  /// Izin "Akses notifikasi" untuk catat. sudah diberikan di Pengaturan.
  final bool listenerAccess;

  /// Boleh mengirim notifikasi (Android 13+ perlu izin).
  final bool canNotify;
  final bool reminder;
  final int reminderHour;

  /// Benar-benar jalan: dinyalakan + izin lengkap.
  bool get active => enabled && listenerAccess && canNotify;

  factory AutoStatus.fromMap(Map<Object?, Object?> m) => AutoStatus(
    enabled: m['enabled'] == true,
    listenerAccess: m['listenerAccess'] == true,
    canNotify: m['canNotify'] == true,
    reminder: m['reminder'] == true,
    reminderHour: (m['reminderHour'] as int?) ?? 21,
  );
}

/// Aplikasi dibuka dari notif catat. / share gambar / pengingat.
sealed class LaunchAction {
  const LaunchAction();
}

/// Ketuk notif "Barusan keluar Rp…". [transaction] null = tidak terbaca jelas.
class CaptureLaunch extends LaunchAction {
  const CaptureLaunch(this.transaction);
  final DetectedTransaction? transaction;
}

/// Gambar dibagikan ke catat. (screenshot bukti transfer / foto struk).
class ShareLaunch extends LaunchAction {
  const ShareLaunch(this.imagePath);
  final String imagePath;
}

class ReminderLaunch extends LaunchAction {
  const ReminderLaunch();
}

/// Ketuk notif "Tercatat …" / tombol "Ubah": buka catatannya.
class RouteLaunch extends LaunchAction {
  const RouteLaunch(this.location);
  final String location;
}

/// Jembatan ke Android (MainActivity, channel id.catat.catat/auto).
/// Di-override di test.
abstract class AutoCaptureBridge {
  Future<AutoStatus> status();
  Future<AutoStatus> setEnabled(bool on);
  Future<AutoStatus> setReminder(bool on);

  /// Buka halaman "Akses notifikasi" di Pengaturan Android.
  Future<void> openAccessSettings();

  /// Minta izin kirim notifikasi (Android 13+). true = diizinkan.
  Future<bool> requestNotifications();

  /// Aksi pembukaan yang menunggu (sekali ambil).
  Future<LaunchAction?> takeLaunch();

  /// Ada aksi baru saat aplikasi sudah terbuka.
  Stream<void> get launches;

  /// Catatan ditambah / dihapus di belakang layar (catat otomatis).
  Stream<void> get dataChanges;
}

class ChannelAutoCaptureBridge implements AutoCaptureBridge {
  ChannelAutoCaptureBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'launch') _launches.add(null);
      if (call.method == 'dataChanged') _dataChanges.add(null);
    });
  }

  static const _channel = MethodChannel('id.catat.catat/auto');
  final _launches = StreamController<void>.broadcast();
  final _dataChanges = StreamController<void>.broadcast();

  Future<AutoStatus> _status(String method, [Object? args]) async {
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>(method, args);
      return m == null ? const AutoStatus() : AutoStatus.fromMap(m);
    } on MissingPluginException {
      return const AutoStatus(); // bukan Android
    }
  }

  @override
  Future<AutoStatus> status() => _status('status');

  @override
  Future<AutoStatus> setEnabled(bool on) => _status('setEnabled', {'on': on});

  @override
  Future<AutoStatus> setReminder(bool on) => _status('setReminder', {'on': on});

  @override
  Future<void> openAccessSettings() =>
      _channel.invokeMethod<void>('openAccessSettings');

  @override
  Future<bool> requestNotifications() async =>
      await _channel.invokeMethod<bool>('requestNotifications') ?? false;

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
      'capture' => CaptureLaunch(
        detectedFromMap(m['capture']! as Map<Object?, Object?>),
      ),
      'share' => ShareLaunch(m['path']! as String),
      'reminder' => const ReminderLaunch(),
      'route' => RouteLaunch(m['route']! as String),
      _ => null,
    };
  }

  @override
  Stream<void> get launches => _launches.stream;

  @override
  Stream<void> get dataChanges => _dataChanges.stream;
}

/// Tangkapan mentah dari Android (pkg, source, title, text, postedAt) → transaksi.
DetectedTransaction? detectedFromMap(Map<Object?, Object?> c) =>
    parseBankNotification(
      packageName: c['pkg']! as String,
      title: c['title']! as String,
      text: c['text']! as String,
      postedAt: DateTime.fromMillisecondsSinceEpoch(c['postedAt']! as int),
      source:
          NotificationSource.values
              .where((s) => s.name == c['source'])
              .firstOrNull ??
          NotificationSource.financeApp,
    );

/// Alamat layar untuk satu aksi pembukaan.
String launchLocation(LaunchAction action) {
  switch (action) {
    case ShareLaunch():
      return '/baca-struk';
    case ReminderLaunch():
      return '/catat';
    case RouteLaunch(:final location):
      return location;
    case CaptureLaunch(transaction: null):
      return '/catat';
    case CaptureLaunch(transaction: final t?):
      final q = {
        'amount': '${t.amount}',
        'title': t.title,
        'time': t.occurredAt.toIso8601String(),
      };
      if (t.direction == MoneyDirection.into) {
        return Uri(path: '/pemasukan', queryParameters: q).toString();
      }
      return Uri(
        path: '/catat',
        queryParameters: {
          ...q,
          'pocketType': t.pocketGuess.name,
          'source': 'notif',
        },
      ).toString();
  }
}
