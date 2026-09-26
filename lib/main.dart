import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'background.dart';

void main() {
  // Plus Jakarta Sans dibundel di google_fonts/ → jangan unduh dari internet,
  // supaya font langsung benar saat pertama dibuka & saat offline.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Plus Jakarta Sans'], license);
  });
  runApp(const ProviderScope(child: CatatApp()));
}

/// Mesin latar belakang catat otomatis (lihat BackgroundRecorder.kt).
@pragma('vm:entry-point')
Future<void> autoRecordMain() => runAutoRecorder();
