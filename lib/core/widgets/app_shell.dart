import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';

/// Kerangka dengan bottom nav: Beranda · Catatan · [Scan] · Laporan · Akun.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: shell,
        bottomNavigationBar: _BottomNav(
          index: shell.currentIndex,
          onTab: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          onScan: () => context.push('/scan'),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.onTab,
    required this.onScan,
  });

  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // Desain: margin 24. HP 320dp tidak muat (4 tab + Scan = 278) → menyusut.
    final side =
        ((MediaQuery.sizeOf(context).width - 4 * _Tab.width - AppSize.fab) / 2)
            .clamp(0.0, 24.0);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(
        side,
        8,
        side,
        bottomInset > 0 ? bottomInset + 6 : 22,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Tab(
            icon: LucideIcons.house,
            label: 'Beranda',
            active: index == 0,
            onTap: () => onTab(0),
          ),
          _Tab(
            icon: LucideIcons.calendar,
            label: 'Catatan',
            active: index == 1,
            onTap: () => onTab(1),
          ),
          _ScanButton(onTap: onScan),
          _Tab(
            icon: LucideIcons.chartPie,
            label: 'Laporan',
            active: index == 2,
            onTap: () => onTab(2),
          ),
          _Tab(
            icon: LucideIcons.user,
            label: 'Akun',
            active: index == 3,
            onTap: () => onTab(3),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  static const width = 56.0;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.ink : AppColors.faint;
    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppText.style(
                11,
                active ? AppText.w800 : AppText.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSize.fab,
            height: AppSize.fab,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
              boxShadow: AppShadow.fab,
            ),
            child: const Icon(
              LucideIcons.scanLine,
              size: 26,
              color: AppColors.lime,
            ),
          ),
          const SizedBox(height: 4),
          Text('Scan', style: AppText.style(11, AppText.w800)),
        ],
      ),
    );
  }
}
