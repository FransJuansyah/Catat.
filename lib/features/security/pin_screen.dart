import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/pin_pad.dart';
import '../../data/providers.dart';
import '../../domain/pin.dart';

/// Buka layar PIN untuk apa: bikin baru, ganti, atau matikan kunci.
enum PinMode { create, change, off }

enum _Step { old, fresh, repeat }

/// Layar 57 · Bikin PIN (juga ganti & matikan: minta PIN lama dulu).
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key, this.mode = PinMode.create});

  final PinMode mode;

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  late _Step _step = widget.mode == PinMode.create ? _Step.fresh : _Step.old;
  String _input = '';
  String _first = '';
  String? _error;
  bool _shake = false;

  (String, String) get _texts => switch (_step) {
    _Step.old => ('Masukin PIN lama', 'Buat mastiin ini beneran kamu.'),
    _Step.fresh => (
      'Bikin PIN 6 angka',
      'Buat buka catat. Jangan pakai tanggal lahir ya.',
    ),
    _Step.repeat => ('Ulangi PIN', 'Ketik sekali lagi PIN yang sama.'),
  };

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _error = message;
      _shake = true;
      _input = '';
    });
  }

  Future<void> _digit(String d) async {
    if (_input.length >= Pin.length) return;
    setState(() {
      _input += d;
      _error = null;
      _shake = false;
    });
    if (_input.length < Pin.length) return;
    final lock = ref.read(appLockProvider);
    switch (_step) {
      case _Step.old:
        if (!lock.checkPin(_input)) return _fail('PIN-nya salah');
        if (widget.mode == PinMode.off) {
          await lock.disable();
          if (mounted) context.pop();
          return;
        }
        setState(() {
          _step = _Step.fresh;
          _input = '';
        });
      case _Step.fresh:
        final weak = Pin.weakness(_input);
        if (weak != null) return _fail(weak);
        setState(() {
          _first = _input;
          _step = _Step.repeat;
          _input = '';
        });
      case _Step.repeat:
        if (_input != _first) {
          _first = '';
          _fail('PIN-nya beda, bikin ulang ya');
          setState(() => _step = _Step.fresh);
          return;
        }
        await lock.setPin(_input);
        if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _texts;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            8,
            AppSpace.screenX,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppTopBar(title: ''),
              const SizedBox(height: 14),
              Text(
                title,
                style: AppText.style(26, AppText.w800, spacingPercent: -3),
              ),
              const SizedBox(height: 6),
              Text(
                _error ?? subtitle,
                style: AppText.style(
                  14,
                  _error != null ? AppText.w700 : AppText.w500,
                  color: _error != null ? AppColors.danger : AppColors.muted,
                ),
              ),
              const SizedBox(height: 36),
              PinDots(filled: _input.length, error: _shake),
              const Spacer(),
              PinPad(
                onDigit: _digit,
                onDelete: () => setState(() {
                  if (_input.isNotEmpty) {
                    _input = _input.substring(0, _input.length - 1);
                  }
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
