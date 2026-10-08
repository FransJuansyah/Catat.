import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/providers.dart';
import '../../domain/bills.dart';

/// Warna ikon tagihan: dari kantongnya kalau ada, selain itu tinta.
Color billColor(Bill b, WidgetRef ref) {
  final pockets = ref.watch(homeSummaryProvider).value?.pockets ?? const [];
  final p = pockets.where((p) => p.id == b.pocketId).firstOrNull;
  return p == null ? AppColors.ink : Color(p.color);
}

/// "Tgl 10 · sisa 8x" / "Tgl 1 · rutin".
String billSubtitle(Bill b) {
  final what = b.kind == BillKind.cicilan
      ? 'sisa ${b.remaining}x'
      : 'tiap bulan';
  return 'Tgl ${b.dueDay} · $what';
}

/// Baris tagihan (layar 69, 73, 75): ikon kotak, nama, keterangan, nominal,
/// pil status opsional.
class BillTile extends ConsumerWidget {
  const BillTile({
    super.key,
    required this.bill,
    this.status,
    this.subtitle,
    this.onTap,
  });

  final Bill bill;
  final Widget? status;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = billColor(bill, ref);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.rowY),
        child: Row(
          children: [
            IconBadge(
              icon: PocketVisuals.icon(bill.iconKey),
              background: color == AppColors.ink
                  ? AppColors.track
                  : PocketVisuals.soft(color),
              color: color,
              size: 42,
              iconSize: 20,
              square: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.style(15, AppText.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle ?? billSubtitle(bill),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.style(
                      12,
                      AppText.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rupiah(bill.amount),
                  style: AppText.style(15, AppText.w800),
                ),
                if (status != null) ...[const SizedBox(height: 4), status!],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pil status kecil: "Besok" (kuning), "6 hari lagi" (abu), "Lunas" (hijau).
class StatusPill extends StatelessWidget {
  const StatusPill.due(int days, {super.key})
    : label = '',
      _days = days,
      _paid = false;

  const StatusPill.paid({super.key}) : label = 'Lunas', _days = 0, _paid = true;

  final String label;
  final int _days;
  final bool _paid;

  @override
  Widget build(BuildContext context) {
    final urgent = !_paid && _days <= 3;
    final late = !_paid && _days < 0;
    final (bg, fg) = _paid
        ? (AppColors.successSoft, AppColors.success)
        : late
        ? (AppColors.dangerSoft, AppColors.danger)
        : urgent
        ? (AppColors.warnBadge, AppColors.warnText)
        : (AppColors.track, AppColors.muted);
    final icon = _paid
        ? LucideIcons.check
        : urgent
        ? LucideIcons.bell
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            _paid ? label : dueLabel(_days),
            style: AppText.style(12, AppText.w800, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Lembar aksi satu tagihan: "Udah bayar" (catat pengeluaran) / "Ubah".
Future<void> showBillActions(
  BuildContext context,
  WidgetRef ref,
  Bill bill,
) async {
  final pockets = ref.read(homeSummaryProvider).value?.pockets ?? const [];
  final pocket = pockets.where((p) => p.id == bill.pocketId).firstOrNull;
  final today = ref.read(clockProvider)();
  final paidNow = bill.paidIn(monthIndex(today));
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (sheet) => SafeArea(
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
              bill.name,
              textAlign: TextAlign.center,
              style: AppText.style(20, AppText.w800, spacingPercent: -2),
            ),
            const SizedBox(height: 6),
            Text(
              bill.finished
                  ? 'Cicilan ini udah lunas semua.'
                  : '${rupiah(bill.amount)} · jatuh tempo ${shortDate(bill.nextDue)}'
                        '${pocket == null ? '' : '\nDicatat dari kantong ${pocket.name}'}',
              textAlign: TextAlign.center,
              style: AppText.style(14, AppText.w500, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            if (!bill.finished) ...[
              AppButton(
                label: paidNow ? 'Bayar bulan depan juga' : 'Udah bayar',
                icon: LucideIcons.check,
                onPressed: () => Navigator.pop(sheet, 'pay'),
              ),
              const SizedBox(height: 10),
            ],
            AppButton(
              label: 'Ubah tagihan',
              style: AppButtonStyle.secondary,
              onPressed: () => Navigator.pop(sheet, 'edit'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'pay':
      await ref.read(billRepositoryProvider).payBill(bill.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${bill.name} lunas, udah dicatat')),
        );
      }
    case 'edit':
      context.push('/tagihan/${bill.id}');
  }
}
