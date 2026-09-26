import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/expense/expense_detail_screen.dart';
import 'features/expense/expense_form_screen.dart';
import 'features/expense/saved_screen.dart';
import 'features/home/home_screen.dart';
import 'features/notes/notes_screen.dart';
import 'features/placeholder_screen.dart';
import 'features/pocket/pocket_detail_screen.dart';

final _router = GoRouter(
  initialLocation: '/beranda',
  routes: [
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
      builder: (_, _) => const PlaceholderScreen(
        title: 'Atur kantong',
        designRef: '20',
        showBack: true,
      ),
      routes: [
        GoRoute(
          path: ':id',
          builder: (_, state) =>
              PocketDetailScreen(pocketId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/gajian-masuk',
      builder: (_, _) => const PlaceholderScreen(
        title: 'Gajian masuk',
        designRef: '18',
        dark: true,
        showBack: true,
      ),
    ),
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
    );
  }
}
