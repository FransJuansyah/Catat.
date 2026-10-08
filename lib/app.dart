import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/app_frame.dart';
import 'core/widgets/app_shell.dart';
import 'data/device_bridge.dart';
import 'data/providers.dart';
import 'data/receipt_scanner.dart';
import 'domain/types.dart';
import 'domain/pro.dart';
import 'features/account/account_screen.dart';
import 'features/account/sign_in_screens.dart';
import 'features/pro/pro_screen.dart';
import 'features/security/lock_screen.dart';
import 'features/security/pin_screen.dart';
import 'features/security/security_screen.dart';
import 'features/pro/pro_unlocked_screen.dart';
import 'features/balance/adjust_balance_screen.dart';
import 'features/expense/expense_detail_screen.dart';
import 'features/expense/expense_form_screen.dart';
import 'features/expense/saved_screen.dart';
import 'features/home/home_screen.dart';
import 'features/income/income_form_screen.dart';
import 'features/income/income_saved_screen.dart';
import 'features/notes/notes_screen.dart';
import 'features/onboarding/allowance_setup_screen.dart';
import 'features/onboarding/irregular_setup_screen.dart';
import 'features/onboarding/opening_balance_screen.dart';
import 'features/onboarding/payslip_reading_screen.dart';
import 'features/onboarding/salary_setup_screen.dart';
import 'features/onboarding/source_screen.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/onboarding/template_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/payday/payday_screen.dart';
import 'features/pocket/pocket_budget_screen.dart';
import 'features/pocket/pocket_detail_screen.dart';
import 'features/pocket/pocket_edit_screen.dart';
import 'features/pocket/pocket_settings_screen.dart';
import 'features/pocket/transfer_screen.dart';
import 'features/privacy/privacy_screen.dart';
import 'features/quick/quick_note_screen.dart';
import 'features/scan/scan_reading_screen.dart';
import 'features/scan/scan_result_screen.dart';
import 'features/report/export_done_screen.dart';
import 'features/bills/bill_edit_screen.dart';
import 'features/onboarding/ai_onboarding_screen.dart';
import 'features/bills/bills_screen.dart';
import 'features/report/export_progress_screen.dart';
import 'features/report/export_screen.dart';
import 'features/report/report_screen.dart';
import 'features/scan/scan_screen.dart';
import 'data/export/report_exporter.dart';

final _router = createRouter();

/// Semua rute aplikasi. [initialLocation]/[initialExtra] dipakai test untuk
/// membuka layar mana pun langsung.
GoRouter createRouter({
  String initialLocation = '/',
  Object? initialExtra,
}) => GoRouter(
  initialLocation: initialLocation,
  initialExtra: initialExtra,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/masuk', builder: (_, _) => const WelcomeScreen()),
    GoRoute(
      path: '/masuk-email',
      builder: (_, state) =>
          SignInEmailScreen(from: state.uri.queryParameters['dari']),
    ),
    GoRoute(
      path: '/masuk-kode',
      builder: (_, state) => SignInCodeScreen(
        email: state.uri.queryParameters['email'] ?? '',
        from: state.uri.queryParameters['dari'],
      ),
    ),
    GoRoute(path: '/sumber-uang', builder: (_, _) => const SourceScreen()),
    GoRoute(path: '/daftar-ai', builder: (_, _) => const AiOnboardingScreen()),
    GoRoute(path: '/atur-gaji', builder: (_, _) => const SalarySetupScreen()),
    GoRoute(
      path: '/baca-slip',
      builder: (_, state) =>
          PayslipReadingScreen(imagePath: state.extra! as String),
    ),
    GoRoute(
      path: '/atur-jajan',
      builder: (_, _) => const AllowanceSetupScreen(),
    ),
    GoRoute(
      path: '/atur-penghasilan',
      builder: (_, _) => const IrregularSetupScreen(),
    ),
    GoRoute(
      path: '/pemasukan',
      builder: (_, state) {
        final q = state.uri.queryParameters;
        return IncomeFormScreen(
          initialDate: DateTime.tryParse(q['date'] ?? ''),
          initialAmount: int.tryParse(q['amount'] ?? ''),
          initialTitle: q['title'],
          initialTime: DateTime.tryParse(q['time'] ?? ''),
          editId: q['edit'],
        );
      },
    ),
    GoRoute(
      path: '/pemasukan-masuk/:id',
      builder: (_, state) =>
          IncomeSavedScreen(incomeId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/pilih-template', builder: (_, _) => const TemplateScreen()),
    // Layar 43: Atur Kantong dalam mode daftar (draft onboarding).
    GoRoute(
      path: '/bikin-kantong',
      builder: (_, _) => const PocketSettingsScreen(),
    ),
    GoRoute(
      path: '/uang-sekarang',
      builder: (_, _) => const OpeningBalanceScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/beranda', builder: (_, _) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/catatan', builder: (_, _) => const NotesScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/laporan', builder: (_, _) => const ReportScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/akun', builder: (_, _) => const AccountScreen()),
          ],
        ),
      ],
    ),
    // Fitur Pro: trial habis & belum beli → layar 53 (lihat ProGate).
    GoRoute(
      path: '/scan',
      builder: (_, _) =>
          const ProGate(feature: ProFeature.scan, child: ScanScreen()),
    ),
    // Layar 60: Catat pakai ketikan (tombol tengah bottom nav).
    GoRoute(path: '/catat-ketik', builder: (_, _) => const QuickNoteScreen()),
    GoRoute(path: '/pro', builder: (_, _) => const ProScreen()),
    GoRoute(path: '/keamanan', builder: (_, _) => const SecurityScreen()),
    GoRoute(
      path: '/pin',
      builder: (_, state) => PinScreen(
        mode: PinMode.values.firstWhere(
          (m) => m.name == state.uri.queryParameters['mode'],
          orElse: () => PinMode.create,
        ),
      ),
    ),
    GoRoute(path: '/pro-kebuka', builder: (_, _) => const ProUnlockedScreen()),
    GoRoute(
      path: '/export',
      builder: (_, state) {
        // ?bulan=2026-09 (bulan yang dilihat di layar Laporan).
        final now = DateTime.now();
        final parsed = DateTime.tryParse(
          '${state.uri.queryParameters['bulan'] ?? ''}-01',
        );
        return ProGate(
          feature: ProFeature.export,
          child: ExportScreen(month: parsed ?? DateTime(now.year, now.month)),
        );
      },
    ),
    GoRoute(
      path: '/export/proses',
      builder: (_, state) =>
          ExportProgressScreen(request: state.extra! as ExportRequest),
    ),
    GoRoute(
      path: '/export/siap',
      builder: (_, state) =>
          ExportDoneScreen(result: state.extra! as ExportResult),
    ),
    GoRoute(
      path: '/baca-struk',
      builder: (_, state) => ProGate(
        feature: ProFeature.scan,
        child: ScanReadingScreen(imagePath: state.extra! as String),
      ),
    ),
    GoRoute(
      path: '/hasil-scan',
      builder: (_, state) =>
          ScanResultScreen(result: state.extra! as ScanResult),
    ),
    GoRoute(
      path: '/catat',
      builder: (_, state) {
        final q = state.uri.queryParameters;
        return ExpenseFormScreen(
          initialDate: DateTime.tryParse(q['date'] ?? ''),
          initialPocketId: q['pocket'],
          editId: q['edit'],
          // Isian awal lewat query: ?amount=&title=&time=&pocketType=&source=
          initialAmount: int.tryParse(q['amount'] ?? ''),
          initialTitle: q['title'],
          initialTime: DateTime.tryParse(q['time'] ?? ''),
          initialPocketType: PocketType.values
              .where((t) => t.name == q['pocketType'])
              .firstOrNull,
          source:
              ExpenseSource.values
                  .where((s) => s.name == q['source'])
                  .firstOrNull ??
              ExpenseSource.manual,
        );
      },
    ),
    GoRoute(
      path: '/tercatat/:id',
      builder: (_, state) =>
          SavedScreen(expenseId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/transaksi/:id',
      builder: (_, state) =>
          ExpenseDetailScreen(expenseId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/kantong',
      builder: (_, _) => const PocketSettingsScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (_, state) =>
              PocketDetailScreen(pocketId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/tagihan',
      builder: (_, state) =>
          BillsScreen(payId: state.uri.queryParameters['bayar']),
      routes: [
        GoRoute(
          path: 'baru',
          builder: (_, state) =>
              BillEditScreen(draft: state.extra as BillDraft?),
        ),
        GoRoute(
          path: ':id',
          builder: (_, state) =>
              BillEditScreen(billId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/edit-kantong/:id',
      builder: (_, state) =>
          PocketEditScreen(pocketId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/jatah-kantong/:id',
      builder: (_, state) =>
          PocketBudgetScreen(pocketId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/pindah-saldo',
      builder: (_, state) => TransferScreen(
        fromId: state.uri.queryParameters['from'],
        toId: state.uri.queryParameters['to'],
      ),
    ),
    GoRoute(path: '/gajian-masuk', builder: (_, _) => const PaydayScreen()),
    // Layar 35 (onboarding) & 37 (dari Akun).
    GoRoute(
      path: '/privasi-awal',
      builder: (_, state) => PrivacyScreen(
        onboarding: true,
        next: state.uri.queryParameters['next'],
      ),
    ),
    GoRoute(path: '/privasi', builder: (_, _) => const PrivacyScreen()),
    GoRoute(
      path: '/sesuaikan-saldo',
      builder: (_, _) => const AdjustBalanceScreen(),
    ),
  ],
);

class CatatApp extends ConsumerStatefulWidget {
  const CatatApp({super.key});

  @override
  ConsumerState<CatatApp> createState() => _CatatAppState();
}

class _CatatAppState extends ConsumerState<CatatApp>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _launches;
  bool? _compact;

  /// HP dikunci tegak (layar keypad tidak muat saat mendatar); tablet & HP
  /// lipat yang dibuka bebas diputar. Dicek ulang saat HP lipat dibuka/ditutup.
  void _applyOrientation() {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view == null || view.physicalSize.isEmpty) return;
    final compact = isCompactScreen(view.physicalSize / view.devicePixelRatio);
    if (compact == _compact) return;
    _compact = compact;
    unawaited(
      SystemChrome.setPreferredOrientations(
        compact ? const [DeviceOrientation.portraitUp] : const [],
      ),
    );
  }

  @override
  void didChangeMetrics() => _applyOrientation();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyOrientation();
    // Dengarkan Google Play sejak awal: pembelian yang selesai saat app
    // tertutup (mis. bayar via DANA belakangan) tetap tercatat.
    ref.listenManual(proProvider, (_, _) {});
    // Aplikasi sudah terbuka lalu share / notif pengingat diketuk.
    _launches = ref.read(deviceBridgeProvider).launches.listen((_) {
      if (ref.read(appReadyProvider)) unawaited(_openLaunch());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_launches?.cancel());
    super.dispose();
  }

  /// Buka layar untuk aksi pembukaan (share gambar, pengingat) di atas
  /// Beranda.
  Future<void> _openLaunch() async {
    final action = await ref.read(deviceBridgeProvider).takeLaunch();
    if (action == null) return;
    unawaited(
      _router.push(
        launchLocation(action),
        extra: action is ShareLaunch ? action.imagePath : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dibuka dingin dari share / pengingat: tunggu Splash sampai di Beranda.
    ref.listen(appReadyProvider, (_, ready) {
      if (ready) unawaited(_openLaunch());
    });
    return MaterialApp.router(
      title: 'catat.',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
      builder: appBuilder,
    );
  }
}

/// Pembungkus semua layar (juga dipakai test): ikon status bar gelap di
/// layar terang (layar gelap menimpa sendiri) + bingkai tablet.
Widget appBuilder(BuildContext context, Widget? child) =>
    AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      // Kunci PIN (layar 58) menutupi semua layar di atas router.
      child: LockGate(
        onPinReset: () => unawaited(_router.push('/pin?mode=create')),
        child: AppFrame(child: child!),
      ),
    );
