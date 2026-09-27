import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/receipt_scanner.dart';
import '../../domain/receipt_lock.dart';
import 'scan_widgets.dart';

/// Layar 04 · Scan Struk (kamera) tanpa tombol jepret: frame kamera dibaca
/// terus, begitu TOTAL kebaca stabil → layar 46 → foto otomatis → 09.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  /// Jeda minimal antar-frame yang dibaca (hemat baterai).
  static const _frameGap = Duration(milliseconds: 350);

  /// Selama ini belum kebaca → tampilkan tips.
  static const _slowAfter = Duration(seconds: 8);

  CameraController? _camera;
  late final ReceiptFrameReader _reader = ReceiptFrameReader(
    ref.read(clockProvider),
  );
  final _lock = ReceiptLock();
  bool _reading = false;
  DateTime _lastFrame = DateTime(0);
  Timer? _slowTimer;
  bool _slow = false;

  /// Pesan kalau kamera tidak bisa dipakai (izin ditolak / tidak ada kamera).
  String? _error;
  bool _flash = false;

  /// Struk kebaca & sedang difoto (layar 46).
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _slowTimer?.cancel();
    _camera?.dispose();
    unawaited(_reader.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive) {
      _camera = null;
      _slowTimer?.cancel();
      camera?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && camera == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (cameras.isEmpty) {
        setState(() => _error = 'Kamera nggak ketemu di HP ini.');
        return;
      }
      final controller = CameraController(
        back.isNotEmpty ? back.first : cameras.first,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        // Frame buat dibaca ML Kit; foto tetap JPEG.
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _error = null;
        _flash = false;
        _busy = false;
        _slow = false;
      });
      await _startReading();
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.code.contains('Access')
            ? 'Izin kamera ditolak. Aktifin di pengaturan HP, atau pilih foto dari Galeri.'
            : 'Kamera belum bisa dibuka. Coba pilih dari Galeri.',
      );
    }
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null) return;
    final next = !_flash;
    try {
      await camera.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _flash = next);
    } on CameraException {
      // HP tanpa flash: abaikan.
    }
  }

  Future<void> _startReading() async {
    final camera = _camera;
    if (camera == null || camera.value.isStreamingImages) return;
    _lock.reset();
    _slowTimer?.cancel();
    _slowTimer = Timer(_slowAfter, () {
      if (mounted && !_busy) setState(() => _slow = true);
    });
    try {
      await camera.startImageStream(_onFrame);
    } on CameraException {
      // Stream tidak didukung: Galeri & Manual tetap bisa dipakai.
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final camera = _camera;
    final now = DateTime.now();
    if (camera == null || _reading || _busy) return;
    if (now.difference(_lastFrame) < _frameGap) return;
    _reading = true;
    _lastFrame = now;
    try {
      final data = await _reader.read(
        image,
        camera.description.sensorOrientation,
      );
      if (data != null && _lock.add(data) && mounted) await _capture();
    } on Object {
      // Frame gagal dibaca: tunggu frame berikutnya.
    } finally {
      _reading = false;
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    setState(() => _busy = true);
    _slowTimer?.cancel();
    unawaited(HapticFeedback.mediumImpact());
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
      final file = await camera.takePicture();
      if (_flash) await camera.setFlashMode(FlashMode.off);
      if (mounted) _read(file.path);
    } on CameraException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _slow = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal ambil foto, coba lagi ya.')),
      );
      await _startReading();
    }
  }

  Future<void> _pickGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null && mounted) _read(file.path);
  }

  void _read(String path) =>
      context.pushReplacement('/baca-struk', extra: path);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screenX,
              8,
              AppSpace.screenX,
              24,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    DarkCircleButton(
                      icon: LucideIcons.x,
                      onTap: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Scan Struk',
                        textAlign: TextAlign.center,
                        style: AppText.style(
                          17,
                          AppText.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DarkCircleButton(
                      icon: _flash ? LucideIcons.zapOff : LucideIcons.zap,
                      active: _flash,
                      onTap: _camera == null ? null : _toggleFlash,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Cadangan kalau struk tidak kebaca otomatis: ketuk kotak.
                Expanded(
                  child: GestureDetector(
                    onTap: _camera == null || _busy ? null : _capture,
                    child: _viewfinder(),
                  ),
                ),
                const SizedBox(height: 20),
                HintPill(
                  text: _busy
                      ? 'Kebaca! Tahan bentar…'
                      : _slow
                      ? 'Belum kebaca? Ketuk kotaknya buat foto'
                      : 'Arahin ke struk, nanti kefoto sendiri',
                  highlight: _busy,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SideAction(
                      icon: LucideIcons.image,
                      label: 'Galeri',
                      onTap: _busy ? null : _pickGallery,
                    ),
                    SideAction(
                      icon: LucideIcons.pencil,
                      label: 'Manual',
                      onTap: () => context.pushReplacement('/catat'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _viewfinder() {
    final camera = _camera;
    final Widget preview;
    if (camera != null && camera.value.isInitialized) {
      final size = camera.value.previewSize!;
      preview = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          // previewSize selalu landscape; layar portrait → dibalik.
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(camera),
          ),
        ),
      );
    } else if (_error != null) {
      preview = Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.cameraOff,
                size: 36,
                color: AppColors.faint,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppText.style(14, AppText.w500, color: AppColors.faint),
              ),
            ],
          ),
        ),
      );
    } else {
      preview = const SizedBox.expand();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.hero),
      child: Container(
        color: AppColors.darkSurface,
        child: Stack(
          children: [
            Positioned.fill(child: preview),
            if (camera != null)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: ScanFrame(locked: _busy),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
