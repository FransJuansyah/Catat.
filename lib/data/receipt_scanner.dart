import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/receipt_parser.dart';

/// Foto struk + hasil bacanya (layar 09 → 05).
class ScanResult {
  const ScanResult({required this.imagePath, required this.data});

  final String imagePath;
  final ReceiptData data;
}

/// Baca teks struk dari foto. Di-override di test.
abstract class ReceiptScanner {
  Future<ReceiptData> read(String imagePath);

  /// Simpan foto ke folder aplikasi (foto kamera/galeri bisa terhapus).
  Future<String> keepPhoto(String imagePath);
}

/// OCR di HP (ML Kit, gratis & offline) + parser struk Indonesia.
class MlKitReceiptScanner implements ReceiptScanner {
  MlKitReceiptScanner(this._now);

  final DateTime Function() _now;

  @override
  Future<ReceiptData> read(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final lines = [
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(
              line.text,
              line.boundingBox.left,
              line.boundingBox.top,
              line.boundingBox.right,
              line.boundingBox.bottom,
            ),
      ];
      return parseReceipt(groupRows(lines), now: _now());
    } finally {
      await recognizer.close();
    }
  }

  @override
  Future<String> keepPhoto(String imagePath) async {
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'struk'),
    );
    await dir.create(recursive: true);
    final ext = p.extension(imagePath).isEmpty
        ? '.jpg'
        : p.extension(imagePath);
    final target = p.join(dir.path, '${const Uuid().v4()}$ext');
    await File(imagePath).copy(target);
    return target;
  }
}
