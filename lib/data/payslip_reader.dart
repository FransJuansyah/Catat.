import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/payslip_parser.dart';
import 'receipt_scanner.dart';

/// Pilih & baca slip gaji (layar 02 → 08). Di-override di test.
abstract class PayslipReader {
  /// Buka pemilih file Android (foto / PDF). Hasilnya gambar di cache
  /// (halaman pertama PDF sudah dirender); null kalau user batal.
  Future<String?> pick();

  Future<PayslipData> read(String imagePath);
}

class DevicePayslipReader implements PayslipReader {
  static const _channel = MethodChannel('id.catat.catat/files');

  @override
  Future<String?> pick() => _channel.invokeMethod<String>('pickSlip');

  /// Slip gaji dokumen pribadi: yang disimpan cuma nominal & tanggal, salinan
  /// gambarnya langsung dibuang setelah dibaca.
  @override
  Future<PayslipData> read(String imagePath) async {
    try {
      return parsePayslip(await readTextRows(imagePath));
    } finally {
      try {
        await File(imagePath).delete();
      } on FileSystemException {
        // Sudah tidak ada: tidak apa-apa.
      }
    }
  }
}
