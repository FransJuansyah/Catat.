import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/list_card.dart';
import '../../core/widgets/progress_track.dart';
import '../../data/providers.dart';
import '../../domain/bills.dart';
import 'bill_widgets.dart';

/// Layar 69 · Tagihan & cicilan: total bulan ini, belum dibayar, udah lunas.
class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key, this.payId});

  /// Dibuka dari notif "Udah bayar": langsung tawarkan bayar tagihan ini.
  final String? payId;

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  bool _offered = false;

  void _offerPay(List<Bill> bills) {
    if (_offered || widget.payId == null) return;
    _offered = true;
    final b = bills.where((b) => b.id == widget.payId).firstOrNull;
    if (b == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showBillActions(context, ref, b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(billsProvider).value;
    final today = ref.watch(clockProvider)();
    final s = bills == null ? null : summarizeBills(bills, today);
    if (bills != null) _offerPay(bills);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenX,
                  8,
                  AppSpace.screenX,
                  16,
                ),
                children: [
                  const AppTopBar(title: 'Tagihan & cicilan'),
                  const SizedBox(height: 16),
                  if (s != null && s.count > 0) ...[
                    _Summary(summary: s),
                    if (s.unpaid.isNotEmpty) ...[
                      _label('Belum dibayar'),
                      ListCard(
                        children: [
                          for (final b in s.unpaid)
                            BillTile(
                              bill: b,
                              status: StatusPill.due(b.daysLeft(today)),
                              onTap: () => showBillActions(context, ref, b),
                            ),
                        ],
                      ),
                    ],
                    if (s.done.isNotEmpty) ...[
                      _label('Udah lunas'),
                      ListCard(
                        children: [
                          for (final b in s.done)
                            BillTile(
                              bill: b,
                              status: const StatusPill.paid(),
                              onTap: () => showBillActions(context, ref, b),
                            ),
                        ],
                      ),
                    ],
                  ] else if (s != null)
                    const _Empty(),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.sparkles,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Bisa juga lewat chat: "cicilan motor 850rb tgl 5"',
                          style: AppText.style(
                            12,
                            AppText.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screenX,
                0,
                AppSpace.screenX,
                16,
              ),
              child: AppButton(
                label: 'Tambah tagihan',
                icon: LucideIcons.plus,
                onPressed: () => context.push('/tagihan/baru'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
    child: Text(
      text,
      style: AppText.style(13, AppText.w700, color: AppColors.muted),
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final BillsSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final paidCount = s.done.length;
    final total = s.monthCount;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tagihan bulan ini',
            style: AppText.style(14, AppText.w500, color: AppColors.faint),
          ),
          const SizedBox(height: 6),
          Text(
            rupiah(s.total),
            style: AppText.style(
              34,
              AppText.w800,
              color: Colors.white,
              spacingPercent: -3,
            ),
          ),
          const SizedBox(height: 14),
          ProgressTrack(
            value: s.total == 0 ? 0 : s.paid / s.total,
            color: AppColors.lime,
            track: AppColors.darkSurface,
            height: 10,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${rupiah(s.paid)} udah lunas',
                  style: AppText.style(
                    13,
                    AppText.w500,
                    color: AppColors.faint,
                  ),
                ),
              ),
              Text(
                '$paidCount dari $total',
                style: AppText.style(13, AppText.w800, color: AppColors.lime),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.calendarClock, size: 32, color: AppColors.ink),
          const SizedBox(height: 10),
          Text('Belum ada tagihan', style: AppText.style(17, AppText.w800)),
          const SizedBox(height: 6),
          Text(
            'Masukin cicilan, kos, atau langganan. Nanti aku ingetin sehari '
            'sebelum jatuh tempo.',
            textAlign: TextAlign.center,
            style: AppText.style(14, AppText.w500, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
