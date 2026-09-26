import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/tokens.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/icon_badge.dart';

/// Layar sementara untuk fitur yang belum dibangun. `designRef` = nomor layar di design/screens/.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.designRef,
    this.dark = false,
    this.showBack = false,
    this.actionLabel,
    this.actionRoute,
  });

  final String title;
  final String designRef;
  final bool dark;
  final bool showBack;

  /// Tombol opsional, mis. "Ketik manual dulu" di layar Scan.
  final String? actionLabel;
  final String? actionRoute;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: dark ? AppColors.ink : AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screenX,
              8,
              AppSpace.screenX,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBack)
                  dark
                      ? GestureDetector(
                          onTap: () => context.pop(),
                          child: const IconBadge(
                            icon: LucideIcons.x,
                            background: AppColors.darkSurface,
                            color: Colors.white,
                            size: 40,
                            iconSize: 20,
                          ),
                        )
                      : CircleIconButton(
                          icon: LucideIcons.chevronLeft,
                          onTap: () => context.pop(),
                        )
                else
                  Text(
                    title,
                    style: AppText.style(
                      26,
                      AppText.w800,
                      color: fg,
                      spacingPercent: -3,
                    ),
                  ),
                const Spacer(),
                Center(
                  child: Column(
                    children: [
                      const IconBadge(
                        icon: LucideIcons.hammer,
                        background: AppColors.lime,
                        color: AppColors.ink,
                        size: 56,
                        square: true,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '$title lagi dibangun',
                        style: AppText.style(17, AppText.w800, color: fg),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Desain: layar $designRef',
                        style: AppText.style(
                          13,
                          AppText.w500,
                          color: AppColors.faint,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (actionLabel != null && actionRoute != null)
                  AppButton(
                    label: actionLabel!,
                    icon: LucideIcons.pencil,
                    style: AppButtonStyle.secondary,
                    onPressed: () => context.pushReplacement(actionRoute!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
