import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/report.dart';
import 'report_pdf.dart';
import 'report_xlsx.dart';

/// File laporan yang sudah jadi (layar 16).
class ExportResult {
  const ExportResult({
    required this.fileName,
    required this.format,
    required this.localPath,
    required this.sizeBytes,
    required this.detail,
    this.uri,
    this.location,
  });

  final String fileName;
  final ExportFormat format;

  /// Salinan di cache aplikasi (untuk "Bagikan").
  final String localPath;
  final int sizeBytes;

  /// "6 halaman" / "3 sheet".
  final String detail;

  /// content:// di folder Download (null = gagal simpan ke Download).
  final String? uri;

  /// "Download" / "folder aplikasi".
  final String? location;

  String get mime => format == ExportFormat.pdf
      ? 'application/pdf'
      : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
}

/// Susun file laporan & simpan ke Download. Di-override di test.
class ReportExporter {
  const ReportExporter();

  static const _channel = MethodChannel('id.catat.catat/downloads');

  /// Bangun file (PDF/Excel) dari [data].
  Future<({Uint8List bytes, String detail})> build(
    ReportData data,
    ExportFormat format, {
    required DateTime createdAt,
  }) async {
    if (format == ExportFormat.excel) {
      return (
        bytes: buildReportXlsx(data, createdAt: createdAt),
        detail: '3 sheet',
      );
    }
    final fonts = ReportFonts(
      regular: await rootBundle.load(
        'google_fonts/PlusJakartaSans-Regular.ttf',
      ),
      bold: await rootBundle.load('google_fonts/PlusJakartaSans-Bold.ttf'),
    );
    final pdf = await buildReportPdf(
      data,
      fonts: fonts,
      createdAt: createdAt,
      photos: await _receiptPhotos(data),
    );
    return (bytes: pdf.bytes, detail: '${pdf.pages} halaman');
  }

  /// Simpan ke cache + folder Download.
  Future<ExportResult> save(
    Uint8List bytes,
    String fileName,
    ExportFormat format,
    String detail,
  ) async {
    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'laporan'),
    );
    await dir.create(recursive: true);
    final local = File(p.join(dir.path, fileName));
    await local.writeAsBytes(bytes, flush: true);
    var result = ExportResult(
      fileName: fileName,
      format: format,
      localPath: local.path,
      sizeBytes: bytes.length,
      detail: detail,
    );
    try {
      final saved = await _channel.invokeMapMethod<String, String>('save', {
        'path': local.path,
        'name': fileName,
        'mime': result.mime,
      });
      result = ExportResult(
        fileName: fileName,
        format: format,
        localPath: local.path,
        sizeBytes: bytes.length,
        detail: detail,
        uri: saved?['uri'],
        location: saved?['location'],
      );
    } on PlatformException {
      // Tetap bisa dibagikan dari salinan cache.
    }
    return result;
  }

  Future<void> open(ExportResult result) =>
      _channel.invokeMethod('open', {'uri': result.uri, 'mime': result.mime});

  /// Foto struk dikecilkan (lebar 720, JPEG 70%) supaya PDF tetap ringan.
  Future<Map<String, Uint8List>> _receiptPhotos(ReportData data) async {
    final photos = <String, Uint8List>{};
    for (final e in data.expenses) {
      final path = e.photoPath;
      if (path == null || photos.containsKey(path)) continue;
      if (photos.length >= maxReceiptPhotos) break;
      final file = File(path);
      if (!await file.exists()) continue;
      final small = await compute(shrinkPhoto, await file.readAsBytes());
      if (small != null) photos[path] = small;
    }
    return photos;
  }
}

/// Kecilkan foto struk (jalan di isolate terpisah).
Uint8List? shrinkPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final resized = upright.width > 720
      ? img.copyResize(upright, width: 720)
      : upright;
  return img.encodeJpg(resized, quality: 70);
}
