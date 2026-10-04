// Alat uji akurasi scan: jalankan ML Kit (persis seperti app) pada semua foto
// di <dokumen app>/korpus lalu simpan baris OCR + posisinya ke korpus_out/*.json.
// Hasilnya ditarik ke test/fixtures/struk/ untuk test parser di laptop.
//
//   CATAT_UJI=1 flutter run -t tool/ocr_dump.dart   (app uji, bukan app asli)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = ValueNotifier('mulai…');
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder(
            valueListenable: status,
            builder: (_, s, _) => Text(s, textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
  );

  final docs = await getApplicationDocumentsDirectory();
  final inDir = Directory(p.join(docs.path, 'korpus'));
  final outDir = Directory(p.join(docs.path, 'korpus_out'))
    ..createSync(recursive: true);
  final files =
      inDir
          .listSync()
          .whereType<File>()
          .where((f) => RegExp(r'\.(jpe?g|png|webp)$').hasMatch(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  var done = 0;
  for (final f in files) {
    final id = p.basenameWithoutExtension(f.path);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(f.path),
      );
      final lines = [
        for (final b in result.blocks)
          for (final l in b.lines)
            [
              l.text,
              l.boundingBox.left.round(),
              l.boundingBox.top.round(),
              l.boundingBox.right.round(),
              l.boundingBox.bottom.round(),
            ],
      ];
      File(p.join(outDir.path, '$id.json'))
          .writeAsStringSync(jsonEncode({'id': id, 'lines': lines}));
    } catch (e) {
      debugPrint('OCR_GAGAL $id $e');
    }
    done++;
    status.value = 'OCR $done / ${files.length}';
  }
  await recognizer.close();
  status.value = 'SELESAI $done';
  debugPrint('OCR_SELESAI $done');
}
