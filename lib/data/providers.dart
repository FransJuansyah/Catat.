import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/home_summary.dart';
import '../domain/usage_charts.dart';
import '../domain/income_schedule.dart';
import '../domain/pocket_config.dart';
import '../domain/pro.dart';
import '../domain/templates.dart';
import '../domain/types.dart';
import '../domain/views.dart';
import 'account.dart';
import 'app_lock.dart';
import 'auto_capture.dart';
import 'export/report_exporter.dart';
import 'local/database.dart';
import 'payslip_reader.dart';
import 'pro_store.dart';
import 'receipt_scanner.dart';
import 'repositories/budget_repository.dart';
import 'repositories/report_repository.dart';
import 'sync/sync_engine.dart';

/// Jam sistem. Di-override di test agar tanggal bisa dikontrol.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) =>
      BudgetRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Pembaca struk (ML Kit). Di-override di test.
final receiptScannerProvider = Provider<ReceiptScanner>(
  (ref) => MlKitReceiptScanner(ref.watch(clockProvider)),
);

/// Pemilih & pembaca slip gaji (F6). Di-override di test.
final payslipReaderProvider = Provider<PayslipReader>(
  (ref) => DevicePayslipReader(),
);

/// Apakah onboarding (gaji + kantong) sudah selesai. Dipakai Splash.
final isSetUpProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(budgetRepositoryProvider).isSetUp(),
);

final homeSummaryProvider = StreamProvider<HomeSummary>(
  (ref) => ref.watch(budgetRepositoryProvider).watchHome(),
);

final paydayProvider = StreamProvider<PaydayInfo>(
  (ref) => ref.watch(budgetRepositoryProvider).watchPayday(),
);

/// Argumen: tanggal (jam diabaikan).
final dayNotesProvider = StreamProvider.autoDispose.family<DayNotes, DateTime>(
  (ref, day) => ref.watch(budgetRepositoryProvider).watchDay(day),
);

/// Argumen: tanggal 1 di bulan yang diminta.
final calendarMonthProvider = StreamProvider.autoDispose
    .family<CalendarMonth, DateTime>(
      (ref, month) => ref
          .watch(budgetRepositoryProvider)
          .watchMonth(month.year, month.month),
    );

final expenseDetailProvider = StreamProvider.autoDispose
    .family<ExpenseDetail?, String>(
      (ref, id) => ref.watch(budgetRepositoryProvider).watchExpense(id),
    );

final pocketDetailProvider = StreamProvider.autoDispose
    .family<PocketDetail?, String>(
      (ref, id) => ref.watch(budgetRepositoryProvider).watchPocket(id),
    );

// ------------------------------------------------------------- onboarding
final incomeDetailProvider = StreamProvider.autoDispose
    .family<IncomeDetail?, String>(
      (ref, id) => ref.watch(budgetRepositoryProvider).watchIncome(id),
    );

// ------------------------------------------------------------- onboarding

/// Isian onboarding (layar 27, 02/28/29, 19) sebelum disimpan.
class OnboardingDraft {
  const OnboardingDraft({
    this.mode = IncomeMode.salary,
    this.amount = 0,
    this.frequency = IncomeFrequency.monthly,
    this.payday = 25,
    this.weekday = 1,
    this.autoAdd = true,
    this.monthlyEstimate = 0,
    this.reminder = true,
    this.template = PocketTemplates.klasik,
  });

  final IncomeMode mode;

  /// Gaji per bulan / uang jajan per siklus. Tidak dipakai untuk tidak tetap.
  final int amount;
  final IncomeFrequency frequency;
  final int payday;
  final int weekday;
  final bool autoAdd;

  /// Perkiraan sebulan (opsional, tidak tetap). 0 = tidak diisi.
  final int monthlyEstimate;
  final bool reminder;
  final PocketTemplate template;

  /// Tombol "Lanjut" di langkah 3 boleh ditekan.
  bool get amountReady => mode == IncomeMode.irregular || amount > 0;

  OnboardingDraft copyWith({
    IncomeMode? mode,
    int? amount,
    IncomeFrequency? frequency,
    int? payday,
    int? weekday,
    bool? autoAdd,
    int? monthlyEstimate,
    bool? reminder,
    PocketTemplate? template,
  }) => OnboardingDraft(
    mode: mode ?? this.mode,
    amount: amount ?? this.amount,
    frequency: frequency ?? this.frequency,
    payday: payday ?? this.payday,
    weekday: weekday ?? this.weekday,
    autoAdd: autoAdd ?? this.autoAdd,
    monthlyEstimate: monthlyEstimate ?? this.monthlyEstimate,
    reminder: reminder ?? this.reminder,
    template: template ?? this.template,
  );
}

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  /// Ganti tipe pemasukan → template & frekuensi default ikut menyesuaikan.
  void setMode(IncomeMode m) => state = state.copyWith(
    mode: m,
    template: PocketTemplates.forMode(m).first,
    frequency: m == IncomeMode.allowance
        ? IncomeFrequency.weekly
        : IncomeFrequency.monthly,
  );
  void setAmount(int v) => state = state.copyWith(amount: v);
  void setFrequency(IncomeFrequency v) => state = state.copyWith(frequency: v);
  void setPayday(int v) => state = state.copyWith(payday: v);
  void setWeekday(int v) => state = state.copyWith(weekday: v);
  void setAutoAdd(bool v) => state = state.copyWith(autoAdd: v);
  void setMonthlyEstimate(int v) => state = state.copyWith(monthlyEstimate: v);
  void setReminder(bool v) => state = state.copyWith(reminder: v);
  void setTemplate(PocketTemplate t) => state = state.copyWith(template: t);

  /// Simpan semuanya & buat periode pertama. [opening] = uang user sekarang
  /// (layar 42), itu yang dibagi ke kantong di periode pertama.
  Future<void> finish({required int opening}) async {
    final repo = ref.read(budgetRepositoryProvider);
    final d = state;
    await repo.setupBudget(
      incomeMode: d.mode,
      netSalary: d.mode == IncomeMode.irregular ? 0 : d.amount,
      frequency: d.frequency,
      payday: d.payday,
      weekday: d.weekday,
      autoAdd: d.autoAdd,
      monthlyEstimate: d.monthlyEstimate > 0 ? d.monthlyEstimate : null,
      incomeReminder: d.mode == IncomeMode.irregular && d.reminder,
      template: d.template,
    );
    await repo.ensureCurrentPeriod();
    // Jarang ada yang daftar pas hari gajian: periode pertama dibagi dari
    // uang aslinya sekarang. Gajian berikutnya baru dibagi normal.
    await repo.setOpeningBalance(opening);
    ref.invalidate(isSetUpProvider);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
      OnboardingController.new,
    );

// ---------------------------------------------------------- atur kantong

/// Isian layar Atur Kantong (20–22) atau Bikin Kantong Sendiri (43) sebelum
/// disimpan.
class PocketDraft {
  const PocketDraft({
    required this.original,
    required this.current,
    this.lastEditedId,
    this.moves = const {},
    this.onboarding = false,
  });

  final PocketSetup original;
  final PocketSetup current;

  /// Kantong terakhir diubah → disorot kalau alokasi belum pas (layar 23).
  final String? lastEditedId;

  /// Kantong tersimpan yang dihapus → kantong tujuan saldo & riwayatnya.
  final Map<String, String> moves;

  /// Masih daftar (layar 43): disimpan ke isian onboarding, bukan ke DB.
  final bool onboarding;

  bool get dirty =>
      moves.isNotEmpty || !listEquals(original.pockets, current.pockets);

  PocketConfig pocket(String id) =>
      current.pockets.firstWhere((p) => p.id == id);

  /// Kantong belum pernah tersimpan (baru ditambah / masih daftar), jadi
  /// belum punya saldo & catatan.
  bool isNew(String id) =>
      onboarding || !original.pockets.any((p) => p.id == id);

  PocketDraft copyWith({
    PocketSetup? current,
    String? lastEditedId,
    Map<String, String>? moves,
  }) => PocketDraft(
    original: original,
    current: current ?? this.current,
    lastEditedId: lastEditedId ?? this.lastEditedId,
    moves: moves ?? this.moves,
    onboarding: onboarding,
  );
}

class PocketDraftController extends AsyncNotifier<PocketDraft> {
  @override
  Future<PocketDraft> build() async {
    final repo = ref.read(budgetRepositoryProvider);
    if (!await repo.isSetUp()) {
      final setup = _onboardingSetup(ref.read(onboardingProvider));
      return PocketDraft(original: setup, current: setup, onboarding: true);
    }
    final setup = await repo.loadPocketSetup();
    return PocketDraft(original: setup, current: setup);
  }

  /// Kantong dari template yang sedang dipilih di onboarding (layar 19 → 43).
  static PocketSetup _onboardingSetup(OnboardingDraft d) {
    final schedule = IncomeSchedule(
      mode: d.mode,
      frequency: d.frequency,
      payday: d.payday,
      weekday: d.weekday,
    );
    return PocketSetup(
      incomeMode: d.mode,
      base: d.mode == IncomeMode.irregular ? 0 : d.amount,
      perNoun: schedule.perNoun,
      pockets: [
        for (final s in d.template.pockets)
          PocketConfig(
            id: const Uuid().v4(),
            type: s.type,
            name: s.name,
            iconKey: s.iconKey,
            color: s.color,
            percent: s.percent,
          ),
      ],
    );
  }

  void _setPockets(
    List<PocketConfig> pockets, {
    String? edited,
    Map<String, String>? moves,
  }) {
    final d = state.value;
    if (d == null) return;
    state = AsyncData(
      d.copyWith(
        current: d.current.copyWith(pockets: pockets),
        lastEditedId: edited,
        moves: moves,
      ),
    );
  }

  /// "Tambah kantong" (layar 20/43). Mengembalikan id kantong baru, atau
  /// null kalau sudah [maxPockets].
  String? addPocket() {
    final d = state.value;
    if (d == null || !d.current.canAdd) return null;
    final pocket = newPocket(
      const Uuid().v4(),
      d.current.pockets,
      icons: pocketIconChoices,
      colors: pocketPalette,
    );
    _setPockets([...d.current.pockets, pocket], edited: pocket.id);
    return pocket.id;
  }

  /// Hapus kantong (layar 45): jatahnya pindah ke [targetId]; kalau sudah
  /// tersimpan, saldo & riwayatnya ikut pindah saat "Simpan".
  void removePocket(String id, String targetId) {
    final d = state.value;
    if (d == null || !d.current.canRemove) return;
    final moves = {
      for (final MapEntry(:key, :value) in d.moves.entries)
        key: value == id ? targetId : value,
      if (!d.isNew(id)) id: targetId,
    };
    _setPockets(
      withoutPocket(d.current.pockets, id, targetId, d.current.base),
      edited: targetId,
      moves: moves,
    );
  }

  /// Ubah satu kantong (layar 21 & 22).
  void updatePocket(PocketConfig pocket) {
    final d = state.value;
    if (d == null) return;
    _setPockets([
      for (final p in d.current.pockets) p.id == pocket.id ? pocket : p,
    ], edited: pocket.id);
  }

  /// Tab Persen / Nominal di layar 20: semua kantong pindah satuan.
  void setAllMode(AllocationMode mode) {
    final d = state.value;
    if (d == null) return;
    _setPockets([
      for (final p in d.current.pockets) p.withMode(mode, d.current.base),
    ]);
  }

  /// [newIndex] = posisi akhir setelah item dipindah.
  void reorder(int oldIndex, int newIndex) {
    final d = state.value;
    if (d == null) return;
    final list = [...d.current.pockets];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    _setPockets(list);
  }

  /// "Rapiin otomatis" (layar 23).
  void autoBalance() {
    final d = state.value;
    if (d == null) return;
    _setPockets(balancePockets(d.current.pockets, d.current.base));
  }

  Future<void> save() async {
    final d = state.value;
    if (d == null) return;
    if (d.onboarding) {
      ref
          .read(onboardingProvider.notifier)
          .setTemplate(
            PocketTemplates.custom(d.current.pockets, d.current.base),
          );
    } else {
      await ref
          .read(budgetRepositoryProvider)
          .savePockets(d.current.pockets, moves: d.moves);
    }
    state = AsyncData(
      PocketDraft(
        original: d.current,
        current: d.current,
        onboarding: d.onboarding,
      ),
    );
  }
}

final pocketDraftProvider =
    AsyncNotifierProvider.autoDispose<PocketDraftController, PocketDraft>(
      PocketDraftController.new,
    );

// --------------------------------------------------------------- laporan

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) =>
      ReportRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Argumen: tanggal 1 bulan laporan (layar 14).
final monthReportProvider = StreamProvider.autoDispose
    .family<MonthReport, DateTime>(
      (ref, month) => ref.watch(reportRepositoryProvider).watchMonth(month),
    );

/// Pemakaian 7 hari terakhir (Beranda, layar 59).
final weekUsageProvider = StreamProvider.autoDispose<WeekUsage>(
  (ref) => ref.watch(reportRepositoryProvider).watchWeek(),
);

/// Penyusun & penyimpan file laporan. Di-override di test.
final reportExporterProvider = Provider<ReportExporter>(
  (ref) => const ReportExporter(),
);

// -------------------------------------------------------- catat otomatis

/// Jembatan notifikasi bank, pengingat & share gambar. Di-override di test.
final autoCaptureProvider = Provider<AutoCaptureBridge>(
  (ref) => ChannelAutoCaptureBridge(),
);

/// Status catat otomatis & pengingat. Di-invalidate saat kembali dari
/// Pengaturan Android.
final autoStatusProvider = FutureProvider.autoDispose<AutoStatus>(
  (ref) => ref.watch(autoCaptureProvider).status(),
);

/// Splash selesai & user sudah di Beranda → aksi pembukaan (notif / share)
/// boleh langsung membuka layarnya.
class AppReadyController extends Notifier<bool> {
  @override
  bool build() => false;

  void markReady() => state = true;
}

final appReadyProvider = NotifierProvider<AppReadyController, bool>(
  AppReadyController.new,
);

// ------------------------------------------------------- akun & sinkron (F8)

/// Login email + server sinkron. Di-override di test.
final accountServiceProvider = Provider<AccountService>(
  (ref) => SupabaseAccountService(),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    ref.watch(databaseProvider),
    ref.watch(accountServiceProvider).remote,
  ),
);

/// Setelah kode benar: data HP & data akun digabung bagaimana.
enum LoginStart {
  /// Akun masih kosong → data di HP ini (kalau ada) diunggah.
  upload,

  /// Akun sudah ada isinya, HP kosong → tarik data akun.
  restore,

  /// Dua-duanya ada isinya → tanya dulu (data HP diganti data akun).
  conflict,
}

class AccountState {
  const AccountState({
    this.email,
    this.syncing = false,
    this.lastSync,
    this.failed = false,
  });

  /// null = belum masuk.
  final String? email;
  final bool syncing;
  final DateTime? lastSync;

  /// Sinkron terakhir gagal (biasanya offline); dicoba lagi otomatis.
  final bool failed;

  bool get signedIn => email != null;

  AccountState copyWith({
    String? email,
    bool clearEmail = false,
    bool? syncing,
    DateTime? lastSync,
    bool? failed,
  }) => AccountState(
    email: clearEmail ? null : email ?? this.email,
    syncing: syncing ?? this.syncing,
    lastSync: lastSync ?? this.lastSync,
    failed: failed ?? this.failed,
  );
}

/// Masih ada perubahan yang belum terkirim & gagal dikirim (offline).
class PendingChangesException implements Exception {
  const PendingChangesException(this.count);

  final int count;
}

class AccountController extends Notifier<AccountState> {
  AccountService get _service => ref.read(accountServiceProvider);
  SyncEngine get _engine => ref.read(syncEngineProvider);

  Timer? _debounce;

  @override
  AccountState build() {
    final service = ref.watch(accountServiceProvider);
    if (!service.available) return const AccountState();
    final auth = service.emailChanges.listen((email) {
      if (email != state.email) state = state.copyWith(email: email);
    });
    // Tiap ada perubahan lokal → kirim sebentar lagi (dikumpulkan dulu).
    final pending = ref.read(syncEngineProvider).watchPending().listen((n) {
      if (n == 0 || !state.signedIn) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 3), syncNow);
    });
    final lifecycle = AppLifecycleListener(onResume: syncNow);
    ref.onDispose(() {
      auth.cancel();
      pending.cancel();
      lifecycle.dispose();
      _debounce?.cancel();
    });
    unawaited(_loadLastSync());
    final email = service.email;
    if (email != null) Future.microtask(syncNow);
    return AccountState(email: email);
  }

  Future<void> _loadLastSync() async {
    final last = await ref.read(syncEngineProvider).lastSyncAt();
    if (last != null) state = state.copyWith(lastSync: last);
  }

  Future<void> sendCode(String email) => _service.sendCode(email);

  /// Kode benar → tentukan nasib data HP ini (lihat [LoginStart]).
  /// Lupa PIN (layar 58): buktikan pemilik akun lewat kode email, tanpa
  /// menyentuh data.
  Future<void> reverify(String code) =>
      _service.verifyCode(state.email ?? '', code);

  Future<LoginStart> verifyCode(String email, String code) async {
    await _service.verifyCode(email, code);
    return decideStart();
  }

  /// Sudah masuk (kode atau link di email) → lihat isi akun & HP ini.
  Future<LoginStart> decideStart() async {
    final remoteHasData = await _service.remote.hasData();
    final localHasData = await ref.read(budgetRepositoryProvider).isSetUp();
    if (!remoteHasData) return LoginStart.upload;
    return localHasData ? LoginStart.conflict : LoginStart.restore;
  }

  /// Lanjutkan login setelah [verifyCode].
  Future<void> finishLogin(LoginStart start) async {
    if (start == LoginStart.upload) {
      await _engine.enqueueAll();
    } else {
      await _engine.wipeLocal();
    }
    state = state.copyWith(email: _service.email);
    await syncNow(rethrowErrors: true);
    ref.invalidate(isSetUpProvider);
  }

  /// Batal di tengah login (mis. tidak jadi mengganti data HP).
  Future<void> cancelLogin() async {
    await _service.signOut();
    state = state.copyWith(clearEmail: true);
  }

  Future<void> syncNow({bool rethrowErrors = false}) async {
    if (!state.signedIn || state.syncing) return;
    state = state.copyWith(syncing: true);
    try {
      await _engine.sync();
      state = state.copyWith(
        syncing: false,
        failed: false,
        lastSync: await _engine.lastSyncAt(),
      );
    } on Object {
      state = state.copyWith(syncing: false, failed: true);
      if (rethrowErrors) rethrow;
    }
  }

  /// Keluar (layar 51): kirim sisa perubahan, lalu kosongkan HP ini.
  /// [force] = tetap keluar walau ada perubahan yang belum terkirim.
  Future<void> signOut({bool force = false}) async {
    if (!force) {
      try {
        await _engine.push();
      } on Object {
        // Offline: dicek di bawah.
      }
      final left = await _engine.pendingCount();
      if (left > 0) throw PendingChangesException(left);
    }
    await _service.signOut();
    await _engine.wipeLocal();
    state = const AccountState();
    ref.invalidate(isSetUpProvider);
  }

  /// Hapus akun & data (layar 52).
  Future<void> deleteAccount() async {
    await _engine.deleteAccount();
    state = const AccountState();
    ref.invalidate(isSetUpProvider);
  }
}

final accountProvider = NotifierProvider<AccountController, AccountState>(
  AccountController.new,
);

// ------------------------------------------------------------ catat. Pro

final proRepositoryProvider = Provider<ProRepository>(
  (ref) => ProRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Toko Google Play. Di-override di test.
final proStoreProvider = Provider<ProStore>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const NoProStore();
  }
  final store = PlayProStore();
  ref.onDispose(store.dispose);
  return store;
});

final proStatusProvider = StreamProvider<ProStatus>(
  (ref) => ref.watch(proRepositoryProvider).watchStatus(),
);

class ProUiState {
  const ProUiState({
    this.price,
    this.buying = false,
    this.pending = false,
    this.message,
    this.unlockedNow = false,
  });

  /// Harga dari Google Play; null → pakai harga desain.
  final String? price;
  final bool buying;

  /// Bayar belum selesai (mis. menunggu konfirmasi e-wallet).
  final bool pending;
  final String? message;

  /// Baru saja berhasil beli → layar 54.
  final bool unlockedNow;

  ProUiState copyWith({
    String? price,
    bool? buying,
    bool? pending,
    String? message,
    bool clearMessage = false,
    bool? unlockedNow,
  }) => ProUiState(
    price: price ?? this.price,
    buying: buying ?? this.buying,
    pending: pending ?? this.pending,
    message: clearMessage ? null : message ?? this.message,
    unlockedNow: unlockedNow ?? this.unlockedNow,
  );
}

/// Pembelian Pro (layar 53). Dibaca sejak app dibuka supaya pembelian yang
/// selesai saat app tertutup tetap tercatat.
class ProController extends Notifier<ProUiState> {
  @override
  ProUiState build() {
    final store = ref.watch(proStoreProvider);
    final sub = store.events.listen(_onEvent);
    ref.onDispose(sub.cancel);
    unawaited(_init(store));
    return const ProUiState();
  }

  Future<void> _init(ProStore store) async {
    final price = await store.price();
    if (price != null) state = state.copyWith(price: price);
    final status = await ref.read(proRepositoryProvider).status();
    if (!status.purchased) {
      try {
        await store.restore();
      } on Object {
        // Offline / bukan dari Play Store: coba lagi lain kali.
      }
    }
  }

  Future<void> _onEvent(ProStoreEvent e) async {
    switch (e.state) {
      case ProPurchaseState.purchased:
        final repo = ref.read(proRepositoryProvider);
        final before = await repo.status();
        await repo.markPurchased(e.token ?? '');
        state = state.copyWith(
          buying: false,
          pending: false,
          clearMessage: true,
          unlockedNow: !before.purchased && (state.buying || state.pending),
        );
      case ProPurchaseState.pending:
        state = state.copyWith(buying: false, pending: true);
      case ProPurchaseState.canceled:
        state = state.copyWith(buying: false, clearMessage: true);
      case ProPurchaseState.error:
        state = state.copyWith(
          buying: false,
          message: 'Pembayaran gagal. Coba lagi ya.',
        );
    }
  }

  Future<void> buy() async {
    state = state.copyWith(buying: true, clearMessage: true);
    try {
      await ref.read(proStoreProvider).buy();
    } on ProStoreUnavailable {
      state = state.copyWith(
        buying: false,
        message: 'Pembayaran belum bisa dibuka. Pastikan catat. dipasang dari Play Store.',
      );
    } on Object {
      state = state.copyWith(
        buying: false,
        message: 'Pembayaran belum bisa dibuka. Cek internet, lalu coba lagi.',
      );
    }
  }

  Future<void> restore() async {
    state = state.copyWith(clearMessage: true);
    try {
      await ref.read(proStoreProvider).restore();
      state = state.copyWith(
        message: 'Kalau pernah beli pakai akun Google ini, Pro kebuka sebentar lagi.',
      );
    } on Object {
      state = state.copyWith(
        message: 'Belum bisa cek pembelian. Coba lagi ya.',
      );
    }
  }

  void seenUnlocked() => state = state.copyWith(unlockedNow: false);
}

final proProvider = NotifierProvider<ProController, ProUiState>(
  ProController.new,
);

// ------------------------------------------------------------ kunci app

bool get _onAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Pengaturan PIN (Keystore). Di-override di test.
final lockStoreProvider = Provider<LockStore>(
  (ref) => _onAndroid ? SecureLockStore() : MemoryLockStore(),
);

/// Sidik jari. Di-override di test.
final biometricProvider = Provider<BiometricAuth>(
  (ref) => _onAndroid ? DeviceBiometricAuth() : const _NoBiometric(),
);

class _NoBiometric implements BiometricAuth {
  const _NoBiometric();

  @override
  Future<bool> available() async => false;

  @override
  Future<bool> authenticate() async => false;
}

final appLockProvider = Provider<AppLock>((ref) {
  final lock = AppLock(
    ref.watch(lockStoreProvider),
    ref.watch(biometricProvider),
    ref.watch(clockProvider),
  );
  unawaited(lock.load());
  ref.onDispose(lock.dispose);
  return lock;
});

final lockStateProvider = StreamProvider<AppLockState>((ref) async* {
  final lock = ref.watch(appLockProvider);
  yield lock.state;
  yield* lock.changes;
});
