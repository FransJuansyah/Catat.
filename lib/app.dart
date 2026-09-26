import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
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
import 'features/placeholder_screen.dart';
import 'features/pocket/pocket_budget_screen.dart';
import 'features/pocket/pocket_detail_screen.dart';
import 'features/pocket/pocket_edit_screen.dart';
import 'features/pocket/pocket_settings_screen.dart';
import 'features/pocket/transfer_screen.dart';

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
      builder: (_, state) => IncomeFormScreen(
        initialDate: DateTime.tryParse(state.uri.queryParameters['date'] ?? ''),
      ),
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
            GoRoute(
              path: '/laporan',
              builder: (_, _) =>
                  const PlaceholderScreen(title: 'Laporan', designRef: '14'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/akun',
              builder: (_, _) =>
                  const PlaceholderScreen(title: 'Akun', designRef: '17'),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/scan',
      builder: (_, _) => const PlaceholderScreen(
        title: 'Scan struk',
        designRef: '04',
        dark: true,
        showBack: true,
        actionLabel: 'Ketik manual dulu',
        actionRoute: '/catat',
      ),
    ),
    GoRoute(
      path: '/catat',
      builder: (_, state) {
        final q = state.uri.queryParameters;
        return ExpenseFormScreen(
          initialDate: DateTime.tryParse(q['date'] ?? ''),
          initialPocketId: q['pocket'],
          editId: q['edit'],
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
  ],
);

class CatatApp extends StatelessWidget {
  const CatatApp({super.key});

  @override
  Widget build(BuildContext context) {
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
