import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote/supabase_sync_remote.dart';
import 'sync/sync_remote.dart';

/// URL & publishable key (atau anon key lama) Supabase lewat `--dart-define-from-file=supabase.env.json`
/// (di-.gitignore). Kosong → app jalan tanpa akun (hanya di HP).
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_KEY');
const cloudEnabled = supabaseUrl != '' && supabaseKey != '';

Future<void> initCloud() async {
  if (!cloudEnabled) return;
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
}

/// Login email + kode 6 angka (layar 47/48). Di-override di test.
abstract class AccountService {
  bool get available;

  /// Email akun yang sedang masuk, null = belum masuk.
  String? get email;
  Stream<String?> get emailChanges;

  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();

  /// Server sinkron untuk akun yang sedang masuk.
  SyncRemote get remote;
}

class SupabaseAccountService implements AccountService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  bool get available => cloudEnabled;

  @override
  String? get email => available ? _client.auth.currentUser?.email : null;

  @override
  Stream<String?> get emailChanges => available
      ? _client.auth.onAuthStateChange.map((s) => s.session?.user.email)
      : const Stream.empty();

  @override
  Future<void> sendCode(String email) =>
      _client.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true);

  @override
  Future<void> verifyCode(String email, String code) => _client.auth.verifyOTP(
    type: OtpType.email,
    email: email.trim(),
    token: code,
  );

  @override
  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);

  @override
  SyncRemote get remote => SupabaseSyncRemote(_client);
}
