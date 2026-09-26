import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';

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
  Future<ReceiptData> read(String imagePath) async =>
      parseReceipt(await readTextRows(imagePath), now: _now());

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

/// OCR di HP (ML Kit): teks foto per baris, kiri → kanan. Dipakai struk & slip.
Future<List<String>> readTextRows(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return groupRows(_ocrLines(result));
  } finally {
    await recognizer.close();
  }
}

List<OcrLine> _ocrLines(RecognizedText result) => [
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

/// Baca struk dari frame kamera yang sedang jalan (scan otomatis, layar 04).
/// Satu recognizer dipakai selama layar kamera terbuka.
class ReceiptFrameReader {
  ReceiptFrameReader(this._now);

  final DateTime Function() _now;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// [rotation] = sensorOrientation kamera (HP dipegang tegak).
  /// null = format frame tidak didukung (hanya NV21 satu plane, Android).
  Future<ReceiptData?> read(CameraImage image, int rotation) async {
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    final result = await _recognizer.processImage(
      InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation:
              InputImageRotationValue.fromRawValue(rotation) ??
              InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      ),
    );
    return parseReceipt(groupRows(_ocrLines(result)), now: _now());
  }

  Future<void> close() => _recognizer.close();
}
