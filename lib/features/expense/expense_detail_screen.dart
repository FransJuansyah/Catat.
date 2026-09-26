import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/list_card.dart';
import '../../data/providers.dart';
import '../../domain/types.dart';
import '../../domain/views.dart';

/// Layar 13 · Detail Transaksi.
class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final String expenseId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Hapus transaksi ini?',
      message: 'Saldo kantongnya akan kembali seperti sebelum dicatat.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    await ref.read(budgetRepositoryProvider).deleteExpense(expenseId);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(expenseDetailProvider(expenseId)).value;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            8,
            AppSpace.screenX,
            16,
          ),
          child: Column(
            children: [
              AppTopBar(
                title: 'Detail',
                trailingIcon: detail == null ? null : LucideIcons.pencil,
                onTrailing: () => context.push('/catat?edit=$expenseId'),
              ),
              Expanded(
                child: detail == null
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.only(top: 20, bottom: 16),
                        children: [
                          _Summary(entry: detail.entry),
                          const SizedBox(height: 20),
                          ListCard(
                            children: [
                              _InfoRow(
                                'Tanggal',
                                fullDate(detail.entry.occurredAt),
                              ),
                              _InfoRow('Jam', clock(detail.entry.occurredAt)),
                              if (detail.merchant != null)
                                _InfoRow('Toko', detail.merchant!),
                              _InfoRow(
                                'Sumber',
                                detail.entry.source == ExpenseSource.scan
                                    ? 'Scan struk'
                                    : 'Catat manual',
                              ),
                            ],
                          ),
                          if (detail.items.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _ReceiptItems(items: detail.items),
                          ],
                          if (detail.note != null) ...[
                            const SizedBox(height: 16),
                            ListCard(
                              children: [_InfoRow('Catatan', detail.note!)],
                            ),
                          ],
                        ],
                      ),
              ),
              if (detail != null)
                AppButton(
                  label: 'Hapus transaksi',
                  icon: LucideIcons.trash2,
                  style: AppButtonStyle.danger,
                  onPressed: () => _delete(context, ref),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.entry});

  final ExpenseEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = Color(entry.pocket.color);
    final soft = PocketVisuals.soft(color);
    return Column(
      children: [
        IconBadge(
          icon: PocketVisuals.icon(entry.iconKey),
          background: soft,
          color: color,
          size: 60,
          iconSize: 28,
        ),
        const SizedBox(height: 8),
        Text(
          entry.title,
          textAlign: TextAlign.center,
          style: AppText.style(17, AppText.w700, color: AppColors.muted),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            rupiahOut(entry.amount),
            style: AppText.style(38, AppText.w800, spacingPercent: -3),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PocketVisuals.icon(entry.pocket.iconKey),
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                'Kantong ${entry.pocket.name}',
                style: AppText.style(12, AppText.w800, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Text(
            label,
            style: AppText.style(14, AppText.w500, color: AppColors.muted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.style(14, AppText.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptItems extends StatelessWidget {
  const _ReceiptItems({required this.items});

  final List<ExpenseLine> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Isi struk', style: AppText.style(14, AppText.w800)),
          for (final item in items) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(
                  child: Text(
                    item.name,
                    style: AppText.style(14, AppText.w500),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'x${item.qty}',
                  style: AppText.style(
                    13,
                    AppText.w500,
                    color: AppColors.faint,
                  ),
                ),
                const Spacer(),
                Text(
                  rupiah(item.price),
                  style: AppText.style(14, AppText.w700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
