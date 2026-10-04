import 'package:catat/data/device_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aplikasi dibuka dari share gambar / notif pengingat.
void main() {
  test('gambar yang dibagikan → baca struk', () {
    expect(launchLocation(const ShareLaunch('/cache/a.jpg')), '/baca-struk');
  });

  test('pengingat harian → catat pakai ketikan', () {
    expect(launchLocation(const ReminderLaunch()), '/catat-ketik');
  });
}
