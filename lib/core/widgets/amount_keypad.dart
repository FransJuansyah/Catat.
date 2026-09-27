import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../theme/tokens.dart';
import 'app_button.dart';

/// Batas nominal yang bisa diketik: 11 digit (Rp 99 miliar).
const maxAmount = 99999999999;

/// Hasil menekan satu tombol keypad: '0'–'9', '000', atau 'del'.
int applyAmountKey(int amount, String key) {
  switch (key) {
    case 'del':
      return amount ~/ 10;
    case '000':
      return amount > 0 && amount * 1000 <= maxAmount ? amount * 1000 : amount;
    default:
      final next = amount * 10 + int.parse(key);
      return next <= maxAmount ? next : amount;
  }
}

/// Keypad angka 4×3 (desain layar 11). Tahan ⌫ untuk menghapus semua.
/// [digitsOnly] = tanpa tombol 000 (kode masuk, layar 48).
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onKey,
    required this.onClear,
    this.keyColor = AppColors.card,
    this.digitsOnly = false,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onClear;
  final Color keyColor;
  final bool digitsOnly;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['000', '0', 'del'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (r, row) in _rows.indexed) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (final (c, key) in row.indexed) ...[
                if (c > 0) const SizedBox(width: 8),
                Expanded(
                  child: key == '000' && digitsOnly
                      ? const SizedBox(height: 54)
                      : Material(
                          color: keyColor,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onKey(key),
                            onLongPress: key == 'del' ? onClear : null,
                            child: SizedBox(
                              height: 54,
                              child: Center(
                                child: key == 'del'
                                    ? const Icon(
                                        LucideIcons.delete,
                                        size: 22,
                                        color: AppColors.ink,
                                      )
                                    : Text(
                                        key,
                                        style: AppText.style(22, AppText.w700),
                                      ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Bottom sheet isi nominal (gaji bulanan, gaji periode). `null` = batal.
Future<int?> showAmountSheet(
  BuildContext context, {
  required String title,
  int initial = 0,
  String confirmLabel = 'Simpan',
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (context) {
      var amount = initial;
      return StatefulBuilder(
        builder: (context, setState) => SafeArea(
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
                const SizedBox(height: 16),
                Text(
                  title,
                  style: AppText.style(
                    13,
                    AppText.w500,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    rupiah(amount),
                    style: AppText.style(
                      40,
                      AppText.w800,
                      color: amount == 0 ? AppColors.faint : AppColors.ink,
                      spacingPercent: -3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AmountKeypad(
                  onKey: (k) =>
                      setState(() => amount = applyAmountKey(amount, k)),
                  onClear: () => setState(() => amount = 0),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: confirmLabel,
                  onPressed: amount > 0
                      ? () => Navigator.pop(context, amount)
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
