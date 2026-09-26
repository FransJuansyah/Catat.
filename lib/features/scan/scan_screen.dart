import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import 'scan_widgets.dart';

/// Layar 04 · Scan Struk (kamera).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? _camera;

  /// Pesan kalau kamera tidak bisa dipakai (izin ditolak / tidak ada kamera).
  String? _error;
  bool _flash = false;
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
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive) {
      _camera = null;
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
        imageFormatGroup: ImageFormatGroup.jpeg,
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
      });
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

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _busy || camera.value.isTakingPicture) return;
    setState(() => _busy = true);
    try {
      final file = await camera.takePicture();
      if (_flash) await camera.setFlashMode(FlashMode.off);
      if (mounted) _read(file.path);
    } on CameraException {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal ambil foto, coba lagi ya.')),
      );
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
                Expanded(child: _viewfinder()),
                const SizedBox(height: 20),
                const HintPill(text: 'Pas-in struk di dalam kotak'),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SideAction(
                      icon: LucideIcons.image,
                      label: 'Galeri',
                      onTap: _busy ? null : _pickGallery,
                    ),
                    ShutterButton(
                      onTap: _camera == null || _busy ? null : _capture,
                      busy: _busy,
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
              const Positioned.fill(
                child: Padding(padding: EdgeInsets.all(28), child: ScanFrame()),
              ),
          ],
        ),
      ),
    );
  }
}
