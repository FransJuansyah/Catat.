import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// lime = tombol utama di atas latar gelap (layar 18, 31).
enum AppButtonStyle { primary, secondary, danger, dangerFilled, lime }

/// Tombol besar full-width (tinggi 56, radius 18). `onPressed: null` = disabled.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = AppButtonStyle.primary,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonStyle style;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (bg, fg, border) = switch ((style, enabled)) {
      (_, false) when !loading => (AppColors.disabledBg, AppColors.muted, null),
      (AppButtonStyle.primary, _) => (AppColors.ink, Colors.white, null),
      (AppButtonStyle.secondary, _) => (
        AppColors.card,
        AppColors.ink,
        AppColors.line,
      ),
      (AppButtonStyle.lime, _) => (AppColors.lime, AppColors.ink, null),
      (AppButtonStyle.dangerFilled, _) => (
        AppColors.danger,
        Colors.white,
        null,
      ),
      (AppButtonStyle.danger, _) => (
        AppColors.card,
        AppColors.danger,
        AppColors.line,
      ),
    };
    return SizedBox(
      width: double.infinity,
      height: AppSize.buttonHeight,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Center(
            child: loading
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: fg),
                        const SizedBox(width: 8),
                      ],
                      // HP kecil / huruf besar: label mengecil, tidak terpotong.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: AppText.style(16, AppText.w700, color: fg),
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
