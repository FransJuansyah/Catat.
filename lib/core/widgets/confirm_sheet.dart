import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_button.dart';

/// Bottom sheet konfirmasi. Mengembalikan `true` jika user menekan [confirmLabel].
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (context) => SafeArea(
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
              title,
              textAlign: TextAlign.center,
              style: AppText.style(20, AppText.w800, spacingPercent: -2),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.style(14, AppText.w500, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: confirmLabel,
              style: danger ? AppButtonStyle.danger : AppButtonStyle.primary,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Batal',
              style: AppButtonStyle.secondary,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
