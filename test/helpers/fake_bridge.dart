import 'package:catat/data/auto_capture.dart';
import 'package:catat/domain/bank_notification_parser.dart';

/// Jembatan Android palsu: menyimpan status & mencatat panggilan.
class FakeBridge implements AutoCaptureBridge {
  FakeBridge([this.state = const AutoStatus()]);

  AutoStatus state;
  final calls = <String>[];

  AutoStatus _copy({
    Set<NotificationSource>? sources,
    bool? cameraGranted,
    bool? canNotify,
    bool? reminder,
  }) => state = AutoStatus(
    sources: sources ?? state.sources,
    cameraGranted: cameraGranted ?? state.cameraGranted,
    listenerAccess: state.listenerAccess,
    canNotify: canNotify ?? state.canNotify,
    reminder: reminder ?? state.reminder,
  );

  @override
  Future<AutoStatus> status() async => state;

  @override
  Future<AutoStatus> setSource(NotificationSource source, bool on) async {
    calls.add('setSource ${source.name} $on');
    return _copy(
      sources: on
          ? {...state.sources, source}
          : ({...state.sources}..remove(source)),
    );
  }

  @override
  Future<AutoStatus> setReminder(bool on) async {
    calls.add('setReminder $on');
    return _copy(reminder: on);
  }

  @override
  Future<void> openAccessSettings() async => calls.add('openAccessSettings');

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

  @override
  Stream<void> get dataChanges => const Stream.empty();
}
