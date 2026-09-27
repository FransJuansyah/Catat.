import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/pin_pad.dart';
import '../../data/account.dart';
import '../../data/providers.dart';
import '../../domain/pin.dart';
import '../account/sign_in_screens.dart' show signInError;

/// Menutupi seluruh app dengan layar 58 saat terkunci. Dipasang di atas
/// router (appBuilder), jadi posisi layar user tetap sama setelah dibuka.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child, required this.onPinReset});

  final Widget child;

  /// Lupa PIN berhasil diverifikasi → buka layar bikin PIN baru.
  final VoidCallback onPinReset;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Didaftarkan sebelum router → tombol back ditangani di sini dulu.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider);
    if (state == AppLifecycleState.paused) lock.paused();
    if (state == AppLifecycleState.resumed) lock.resumed();
  }

  /// Terkunci: back tidak boleh mundur di layar yang tertutup → tutup app.
  @override
  Future<bool> didPopRoute() async {
    if (!(ref.read(lockStateProvider).value?.locked ?? false)) return false;
    await SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockStateProvider).value;
    final covering = lock == null || !lock.loaded || lock.locked;
    return Stack(
      children: [
        // Isi app tidak ikut terbaca TalkBack / terlihat di belakang kunci.
        ExcludeSemantics(excluding: covering, child: widget.child),
        if (lock == null || !lock.loaded)
          const Positioned.fill(child: ColoredBox(color: AppColors.ink))
        else if (lock.locked)
          Positioned.fill(child: LockScreen(onPinReset: widget.onPinReset)),
      ],
    );
  }
}

enum _Step { pin, forgot, code }

/// Layar 58 · catat. terkunci.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onPinReset});

  final VoidCallback onPinReset;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  _Step _step = _Step.pin;
  String _input = '';
  bool _error = false;
  bool _busy = false;
  String? _message;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Sidik jari langsung ditawarkan begitu layar muncul.
    WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _blockedSeconds > 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _blockedSeconds => ref
      .read(appLockProvider)
      .state
      .throttle
      .secondsLeft(ref.read(clockProvider)());

  Future<void> _biometric() async {
    final lock = ref.read(appLockProvider);
    if (!lock.state.biometric) return;
    await lock.unlockWithBiometric();
  }

  void _digit(String d) {
    if (_busy || _input.length >= Pin.length) return;
    setState(() {
      _input += d;
      _error = false;
    });
    if (_input.length < Pin.length) return;
    if (_step == _Step.code) {
      unawaited(_verifyCode());
      return;
    }
    final ok = ref.read(appLockProvider).unlockWithPin(_input);
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _input = '';
      });
    }
  }

  Future<void> _sendCode() async {
    final email = ref.read(accountProvider).email;
    if (email == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountProvider.notifier).sendCode(email);
      setState(() {
        _step = _Step.code;
        _input = '';
        _message = null;
      });
    } on Object catch (e) {
      setState(() => _message = signInError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() => _busy = true);
    try {
      await ref.read(accountProvider.notifier).reverify(_input);
      await ref.read(appLockProvider).disable();
      widget.onPinReset();
    } on Object catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _input = '';
        _message = signInError(e, code: true);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _mask(String email) {
    final at = email.indexOf('@');
    if (at < 1) return email;
    return '${email[0]}${'•' * (at - 1).clamp(1, 6)}${email.substring(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockStateProvider).value;
    final email = ref.watch(accountProvider).email;
    final wait = _blockedSeconds;
    final (title, subtitle) = switch (_step) {
      _Step.pin => (
        'Masukin PIN',
        wait > 0
            ? 'Kebanyakan salah. Coba lagi $wait detik lagi'
            : 'catat. dikunci biar datamu aman',
      ),
      _Step.forgot => (
        'Lupa PIN?',
        email == null
            ? 'Hapus data catat. di pengaturan HP buat mulai ulang.'
            : 'Kami kirim kode ke ${_mask(email)}. Datamu nggak hilang.',
      ),
      _Step.code => (
        'Masukin kode',
        'Kode 6 angka dari email ${_mask(email ?? '')}',
      ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Material(
        color: AppColors.ink,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screenX,
              40,
              AppSpace.screenX,
              8,
            ),
            child: Column(
              children: [
                const IconBadge(
                  icon: LucideIcons.wallet,
                  background: AppColors.lime,
                  color: AppColors.ink,
                  size: 64,
                  iconSize: 30,
                  square: true,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: AppText.style(
                    24,
                    AppText.w800,
                    color: Colors.white,
                    spacingPercent: -2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _message ?? subtitle,
                  textAlign: TextAlign.center,
                  style: AppText.style(
                    14,
                    AppText.w500,
                    color: _message != null || wait > 0
                        ? AppColors.danger
                        : AppColors.faint,
                  ),
                ),
                const SizedBox(height: 28),
                if (_step != _Step.forgot)
                  PinDots(
                    filled: _input.length,
                    color: AppColors.lime,
                    empty: AppColors.darkSurface,
                    error: _error,
                  ),
                const Spacer(),
                if (_step == _Step.forgot) ...[
                  if (email != null)
                    AppButton(
                      label: 'Kirim kode',
                      style: AppButtonStyle.lime,
                      loading: _busy,
                      onPressed: _sendCode,
                    ),
                  const SizedBox(height: 8),
                ] else
                  PinPad(
                    keyColor: AppColors.darkSurface,
                    textColor: Colors.white,
                    enabled: !_busy && wait == 0,
                    leftIcon: _step == _Step.pin && (lock?.biometric ?? false)
                        ? LucideIcons.fingerprint
                        : null,
                    onLeft: _biometric,
                    onDigit: _digit,
                    onDelete: () => setState(() {
                      if (_input.isNotEmpty) {
                        _input = _input.substring(0, _input.length - 1);
                      }
                    }),
                  ),
                TextButton(
                  onPressed: () => setState(() {
                    _step = _step == _Step.pin ? _Step.forgot : _Step.pin;
                    _input = '';
                    _error = false;
                    _message = null;
                  }),
                  child: Text(
                    _step == _Step.pin ? 'Lupa PIN?' : 'Balik ke PIN',
                    style: AppText.style(
                      14,
                      AppText.w700,
                      color: AppColors.faint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PIN hanya boleh dinyalakan kalau "Lupa PIN" punya jalan keluar: sudah
/// masuk akun (build dengan akun), atau build lokal tanpa akun.
bool canUsePin({required bool signedIn}) => !cloudEnabled || signedIn;
