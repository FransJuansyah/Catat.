import 'package:catat/data/device_bridge.dart';

/// Jembatan Android palsu: menyimpan status & mencatat panggilan.
class FakeBridge implements DeviceBridge {
  FakeBridge([this.state = const DeviceStatus()]);

  DeviceStatus state;
  final calls = <String>[];

  DeviceStatus _copy({bool? cameraGranted, bool? canNotify, bool? reminder}) =>
      state = DeviceStatus(
        cameraGranted: cameraGranted ?? state.cameraGranted,
        canNotify: canNotify ?? state.canNotify,
        reminder: reminder ?? state.reminder,
      );

  @override
  Future<DeviceStatus> status() async => state;

  @override
  Future<DeviceStatus> setReminder(bool on) async {
    calls.add('setReminder $on');
    return _copy(reminder: on);
  }

  @override
  Future<void> openAppSettings() async => calls.add('openAppSettings');

  @override
  Future<bool> requestNotifications() async {
    calls.add('requestNotifications');
    _copy(canNotify: true);
    return true;
  }

  @override
  Future<bool> requestCamera() async {
    calls.add('requestCamera');
    _copy(cameraGranted: true);
    return true;
  }

  @override
  Future<LaunchAction?> takeLaunch() async => null;

  @override
  Stream<void> get launches => const Stream.empty();
}
