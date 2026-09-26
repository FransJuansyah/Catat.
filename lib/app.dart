import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'data/auto_capture.dart';
import 'data/providers.dart';
import 'data/receipt_scanner.dart';
import 'domain/types.dart';
import 'features/account/account_screen.dart';
import 'features/expense/expense_detail_screen.dart';
import 'features/expense/expense_form_screen.dart';
import 'features/expense/saved_screen.dart';
import 'features/home/home_screen.dart';
import 'features/income/income_form_screen.dart';
import 'features/income/income_saved_screen.dart';
import 'features/notes/notes_screen.dart';
import 'features/onboarding/allowance_setup_screen.dart';
import 'features/onboarding/irregular_setup_screen.dart';
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
import 'features/scan/scan_reading_screen.dart';
import 'features/scan/scan_result_screen.dart';
import 'features/report/export_done_screen.dart';
import 'features/report/export_progress_screen.dart';
import 'features/report/export_screen.dart';
import 'features/report/report_screen.dart';
import 'features/scan/scan_screen.dart';
import 'data/export/report_exporter.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/masuk', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/sumber-uang', builder: (_, _) => const SourceScreen()),
    GoRoute(path: '/atur-gaji', builder: (_, _) => const SalarySetupScreen()),
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
        // ?amount=&title=&time= (dari notifikasi uang masuk).
        final q = state.uri.queryParameters;
        return IncomeFormScreen(
          initialDate: DateTime.tryParse(q['date'] ?? ''),
          initialAmount: int.tryParse(q['amount'] ?? ''),
          initialTitle: q['title'],
          initialTime: DateTime.tryParse(q['time'] ?? ''),
        );
      },
    ),
    GoRoute(
      path: '/pemasukan-masuk/:id',
      builder: (_, state) =>
          IncomeSavedScreen(incomeId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/pilih-template', builder: (_, _) => const TemplateScreen()),
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
    GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
    GoRoute(
      path: '/export',
      builder: (_, state) {
        // ?bulan=2026-09 (bulan yang dilihat di layar Laporan).
        final now = DateTime.now();
        final parsed = DateTime.tryParse(
          '${state.uri.queryParameters['bulan'] ?? ''}-01',
        );
        return ExportScreen(month: parsed ?? DateTime(now.year, now.month));
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
      builder: (_, state) =>
          ScanReadingScreen(imagePath: state.extra! as String),
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
          // Dari notifikasi bank: ?amount=&title=&time=&pocketType=&source=
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
  ],
);

class CatatApp extends ConsumerStatefulWidget {
  const CatatApp({super.key});

  @override
  ConsumerState<CatatApp> createState() => _CatatAppState();
}

class _CatatAppState extends ConsumerState<CatatApp> {
  StreamSubscription<void>? _launches;
  StreamSubscription<void>? _dataChanges;

  @override
  void initState() {
    super.initState();
    final bridge = ref.read(autoCaptureProvider);
    // Aplikasi sudah terbuka lalu notif catat. / share diketuk.
    _launches = bridge.launches.listen((_) {
      if (ref.read(appReadyProvider)) unawaited(_openLaunch());
    });
    // Catat otomatis menulis lewat koneksi DB lain → layar ikut dimuat ulang.
    _dataChanges = bridge.dataChanges.listen((_) {
      final db = ref.read(databaseProvider);
      db.markTablesUpdated([
        db.expenses,
        db.expenseItems,
        db.incomes,
        db.incomeAllocations,
      ]);
    });
  }

  @override
  void dispose() {
    unawaited(_launches?.cancel());
    unawaited(_dataChanges?.cancel());
    super.dispose();
  }

  /// Buka layar untuk aksi pembukaan (notif bank, share gambar, pengingat)
  /// di atas Beranda.
  Future<void> _openLaunch() async {
    final action = await ref.read(autoCaptureProvider).takeLaunch();
    if (action == null) return;
    if (action is ShareLaunch) {
      unawaited(_router.push('/baca-struk', extra: action.imagePath));
    } else {
      unawaited(_router.push(launchLocation(action)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dibuka dingin dari notif: tunggu Splash sampai di Beranda.
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
      // Ikon status bar gelap di layar terang; layar gelap menimpa sendiri.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: child!,
      ),
    );
  }
}
