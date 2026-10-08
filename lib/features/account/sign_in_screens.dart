import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/providers.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Pesan error login yang bisa dipahami user.
String signInError(Object e, {bool code = false}) {
  final text = e is AuthException ? '${e.statusCode} ${e.message}' : '$e';
  final lower = text.toLowerCase();
  if (lower.contains('429') || lower.contains('rate')) {
    return 'Kebanyakan minta kode. Tunggu sebentar, lalu coba lagi.';
  }
  // Server email (SMTP / template) bermasalah — bukan salah user.
  if (lower.contains('500') || lower.contains('sending')) {
    return 'Email belum bisa dikirim dari server. Coba lagi sebentar lagi.';
  }
  if (code && (lower.contains('expired') || lower.contains('invalid'))) {
    return 'Kodenya salah atau udah kedaluwarsa.';
  }
  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('host')) {
    return 'Nggak ada internet. Cek koneksimu dulu ya.';
  }
  return code
      ? 'Kodenya belum bisa dicek. Coba lagi ya.'
      : 'Kode belum kekirim. Coba lagi ya.';
}

/// Layar 47 · Masuk pakai email. [from] = 'akun' kalau dibuka dari layar Akun.
class SignInEmailScreen extends ConsumerStatefulWidget {
  const SignInEmailScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<SignInEmailScreen> createState() => _SignInEmailScreenState();
}

class _SignInEmailScreenState extends ConsumerState<SignInEmailScreen> {
  final _email = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _email.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _email.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _valid => _emailRe.hasMatch(_email.text.trim());

  Future<void> _send() async {
    final email = _email.text.trim();
    setState(() => _sending = true);
    try {
      await ref.read(accountProvider.notifier).sendCode(email);
      if (!mounted) return;
      unawaited(
        context.push(
          Uri(
            path: '/masuk-kode',
            queryParameters: {'email': email, 'dari': ?widget.from},
          ).toString(),
        ),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = signInError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
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
                      'Masuk pakai email',
                      style: AppText.style(
                        26,
                        AppText.w800,
                        spacingPercent: -3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kami kirim kode 6 angka ke emailmu. Nggak perlu password.',
                      style: AppText.style(
                        14,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Email',
                      style: AppText.style(
                        13,
                        AppText.w700,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(
                          color: _error != null
                              ? AppColors.danger
                              : focused
                              ? AppColors.ink
                              : AppColors.line,
                          width: focused || _error != null ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.mail,
                            size: 20,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _email,
                              focusNode: _focus,
                              autofocus: true,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) =>
                                  _valid && !_sending ? _send() : null,
                              style: AppText.style(16, AppText.w700),
                              cursorColor: AppColors.ink,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'nama@email.com',
                                hintStyle: AppText.style(
                                  15,
                                  AppText.w500,
                                  color: AppColors.faint,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: AppText.style(
                          13,
                          AppText.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.lock,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Datamu tersimpan di akun, bisa dibuka lagi di HP lain',
                              style: AppText.style(
                                12,
                                AppText.w500,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Kirim kode',
                      loading: _sending,
                      onPressed: _valid ? _send : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layar 48 · Masukin kode 6 angka. Angka ke-6 diketik → langsung dicek.
/// Email tanpa kode (template bawaan Supabase) berisi link: diketuk → app
/// terbuka lagi di layar ini & lanjut sendiri.
class SignInCodeScreen extends ConsumerStatefulWidget {
  const SignInCodeScreen({super.key, required this.email, this.from});

  final String email;
  final String? from;

  @override
  ConsumerState<SignInCodeScreen> createState() => _SignInCodeScreenState();
}

class _SignInCodeScreenState extends ConsumerState<SignInCodeScreen> {
  static const _length = 6;
  static const _resendAfter = 60;

  String _code = '';
  bool _checking = false;
  String? _error;
  int _wait = _resendAfter;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _wait = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_wait <= 1) t.cancel();
      setState(() => _wait--);
    });
  }

  void _key(String k) {
    if (_checking) return;
    setState(() {
      _error = null;
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
      } else if (_code.length < _length) {
        _code += k;
      }
    });
    if (_code.length == _length) unawaited(_verify());
  }

  Future<void> _verify() => _signIn(
    () => ref.read(accountProvider.notifier).verifyCode(widget.email, _code),
  );

  /// Link "Sign in" di email diketuk → app terbuka lagi & sudah masuk.
  void _signedInByLink() {
    if (_checking) return;
    unawaited(_signIn(ref.read(accountProvider.notifier).decideStart));
  }

  Future<void> _signIn(Future<LoginStart> Function() check) async {
    final account = ref.read(accountProvider.notifier);
    setState(() => _checking = true);
    try {
      var start = await check();
      if (!mounted) return;
      if (start == LoginStart.conflict) {
        final choice = await _chooseData(context);
        if (choice == null) {
          await account.cancelLogin();
          if (mounted) context.pop();
          return;
        }
        start = choice;
      }
      await account.finishLogin(start);
      if (!mounted) return;
      final setUp = await ref.read(budgetRepositoryProvider).isSetUp();
      if (!mounted) return;
      if (!setUp) {
        context.go('/daftar-ai');
      } else {
        context.go(widget.from == 'akun' ? '/akun' : '/beranda');
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = signInError(e, code: true);
        _code = '';
        _checking = false;
      });
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(accountProvider.notifier).sendCode(widget.email);
      _startTimer();
    } on Object catch (e) {
      if (mounted) setState(() => _error = signInError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountProvider.select((a) => a.signedIn), (was, now) {
      if (was != true && now) _signedInByLink();
    });
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
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
                      'Cek emailmu',
                      style: AppText.style(
                        26,
                        AppText.w800,
                        spacingPercent: -3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kode 6 angka udah dikirim ke ${widget.email}',
                      style: AppText.style(
                        14,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        for (var i = 0; i < _length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: _digit(i)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_checking)
                      Text(
                        'Lagi dicek…',
                        style: AppText.style(
                          13,
                          AppText.w700,
                          color: AppColors.muted,
                        ),
                      )
                    else if (_error != null)
                      Text(
                        _error!,
                        style: AppText.style(
                          13,
                          AppText.w700,
                          color: AppColors.danger,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Text(
                            'Belum masuk? ',
                            style: AppText.style(
                              13,
                              AppText.w500,
                              color: AppColors.muted,
                            ),
                          ),
                          GestureDetector(
                            onTap: _wait > 0 ? null : _resend,
                            child: Text(
                              _wait > 0
                                  ? 'Kirim ulang 0:${_wait.toString().padLeft(2, '0')}'
                                  : 'Kirim ulang',
                              style: AppText.style(
                                13,
                                AppText.w700,
                                color: _wait > 0
                                    ? AppColors.faint
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    AmountKeypad(
                      digitsOnly: true,
                      onKey: _key,
                      onClear: () => setState(() => _code = ''),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _digit(int i) {
    final active = i == _code.length && !_checking;
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _error != null
              ? AppColors.danger
              : active
              ? AppColors.ink
              : AppColors.line,
          width: active || _error != null ? 2 : 1,
        ),
      ),
      child: Text(
        i < _code.length ? _code[i] : '',
        style: AppText.style(24, AppText.w800),
      ),
    );
  }
}

/// Akun & HP sama-sama berisi: pakai data yang mana. null = batal.
Future<LoginStart?> _chooseData(BuildContext context) =>
    showModalBottomSheet<LoginStart>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.disabledBg,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Akun ini udah ada isinya',
                textAlign: TextAlign.center,
                style: AppText.style(20, AppText.w800, spacingPercent: -2),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih data yang mau dipakai. Data yang nggak dipilih bakal '
                'diganti.',
                textAlign: TextAlign.center,
                style: AppText.style(14, AppText.w500, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Pakai data HP ini',
                onPressed: () => Navigator.pop(sheet, LoginStart.keepLocal),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Pakai data akun',
                style: AppButtonStyle.danger,
                onPressed: () => Navigator.pop(sheet, LoginStart.restore),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Batal',
                style: AppButtonStyle.secondary,
                onPressed: () => Navigator.pop(sheet),
              ),
            ],
          ),
        ),
      ),
    );
