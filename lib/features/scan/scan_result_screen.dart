import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/pocket_chip.dart';
import '../../data/providers.dart';
import '../../data/receipt_scanner.dart';
import '../../data/repositories/budget_repository.dart';
import '../../domain/home_summary.dart';
import '../../domain/receipt_parser.dart';
import '../../domain/types.dart';

const _warnBg = Color(0xFFFFF6DB);
const _warnText = Color(0xFF8A5A00);

/// Layar 05 · Cek Hasil Scan.
class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({super.key, required this.result});

  final ScanResult result;

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  late String? _merchant = widget.result.data.merchant;
  late int _total = widget.result.data.total ?? 0;
  late final DateTime _date =
      widget.result.data.date ?? ref.read(clockProvider)();
  String? _pocketId;
  bool _saving = false;

  ReceiptData get _data => widget.result.data;

  Future<void> _editMerchant() async {
    final controller = TextEditingController(text: _merchant ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nama toko'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Mis. Indomaret Sudirman',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(() => _merchant = value.trim().isEmpty ? null : value.trim());
    }
  }

  Future<void> _editTotal() async {
    final value = await showAmountSheet(
      context,
      title: 'Total belanja',
      initial: _total,
      confirmLabel: 'Pakai',
    );
    if (value != null && mounted) setState(() => _total = value);
  }

  Future<void> _save(String pocketId) async {
    setState(() => _saving = true);
    final repo = ref.read(budgetRepositoryProvider);
    final scanner = ref.read(receiptScannerProvider);
    try {
      final photo = await scanner.keepPhoto(widget.result.imagePath);
      final items = [
        for (final i in _data.items)
          ExpenseItemInput(i.name, i.price, qty: i.qty),
      ];
      Future<String> add(DateTime when) => repo.addExpense(
        pocketId: pocketId,
        amount: _total,
        title: _merchant ?? 'Belanja',
        occurredAt: when,
        source: ExpenseSource.scan,
        merchant: _merchant,
        photoPath: photo,
        items: items,
      );
      String id;
      try {
        id = await add(_date);
      } on StateError {
        // Tanggal di struk di luar periode yang tercatat → catat hari ini.
        id = await add(ref.read(clockProvider)());
      }
      if (mounted) context.pushReplacement('/tercatat/$id');
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan, coba lagi ya.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pockets =
        ref.watch(homeSummaryProvider).value?.pockets ?? const <PocketView>[];
    final guessType = guessPocketType(_data);
    final guessed = pockets.where((p) => p.type == guessType).firstOrNull;
    final selectedId = _pocketId ?? guessed?.id;

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
                  const AppTopBar(title: 'Cek Hasil Scan'),
                  const SizedBox(height: 16),
                  _StatusBanner(data: _data, total: _total),
                  const SizedBox(height: 14),
                  _receiptCard(),
                  const SizedBox(height: AppSpace.section),
                  Text(
                    'Masuk ke kantong mana?',
                    style: AppText.style(17, AppText.w800, spacingPercent: -1),
                  ),
                  if (guessed != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          size: 14,
                          color: Color(0xFF6D5DFC),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tebakan kami: ${guessed.name} (${pocketGuessReason(guessType)})',
                            style: AppText.style(
                              13,
                              AppText.w500,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  ChipRows(
                    children: [
                      for (final p in pockets)
                        _PocketTile(
                          pocket: p,
                          selected: p.id == selectedId,
                          onTap: () => setState(() => _pocketId = p.id),
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
                8,
              ),
              child: Column(
                children: [
                  AppButton(
                    label: 'Simpan pengeluaran',
                    loading: _saving,
                    onPressed: _total > 0 && selectedId != null
                        ? () => _save(selectedId)
                        : null,
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => context.pushReplacement('/scan'),
                    child: Text(
                      'Scan ulang',
                      style: AppText.style(
                        14,
                        AppText.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptCard() {
    final muted = AppText.style(13, AppText.w500, color: AppColors.muted);
    return Container(
      padding: const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const IconBadge(
                icon: LucideIcons.fileText,
                background: AppColors.bg,
                color: AppColors.ink,
                size: 48,
                square: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _merchant ?? 'Nama toko?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.style(
                        17,
                        AppText.w800,
                        color: _merchant == null
                            ? AppColors.faint
                            : AppColors.ink,
                      ),
                    ),
                    Text(
                      _data.date == null
                          ? '${dayTitle(_date)} · tanggal struk nggak kebaca'
                          : '${dayTitle(_date)} · ${clock(_date)}',
                      style: muted,
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.bg,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _editMerchant,
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      LucideIcons.pencil,
                      size: 16,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_data.items.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.line),
            ),
            for (final item in _data.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: item.name),
                            TextSpan(
                              text: '  x${item.qty}',
                              style: AppText.style(
                                13,
                                AppText.w500,
                                color: AppColors.faint,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.style(14, AppText.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      rupiah(item.price),
                      style: AppText.style(14, AppText.w700),
                    ),
                  ],
                ),
              ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.line),
          ),
          InkWell(
            onTap: _editTotal,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Text(
                  'Total',
                  style: AppText.style(
                    15,
                    AppText.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  LucideIcons.pencil,
                  size: 13,
                  color: AppColors.faint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _total > 0 ? rupiah(_total) : 'Isi total',
                      style: AppText.style(
                        _total > 0 ? 28 : 18,
                        AppText.w800,
                        color: _total > 0 ? AppColors.ink : AppColors.danger,
                        spacingPercent: -2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status baca: yakin (hijau), perlu dicek (kuning), gagal (kuning + minta isi).
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.data, required this.total});

  final ReceiptData data;
  final int total;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, text) = data.confident
        ? (
            const Color(0xFFE2F6EC),
            const Color(0xFF0B6B45),
            LucideIcons.check,
            'Struk kebaca! Cek bentar ya',
          )
        : data.total == null
        ? (
            _warnBg,
            _warnText,
            LucideIcons.triangleAlert,
            'Totalnya belum kebaca. Ketuk total buat isi manual ya',
          )
        : (
            _warnBg,
            _warnText,
            LucideIcons.eye,
            'Kebaca, tapi cek lagi totalnya ya',
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.style(14, AppText.w800, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _PocketTile extends StatelessWidget {
  const _PocketTile({
    required this.pocket,
    required this.selected,
    required this.onTap,
  });

  final PocketView pocket;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(pocket.color);
    return Material(
      color: selected ? color : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: selected
            ? BorderSide.none
            : const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              IconBadge(
                icon: selected
                    ? LucideIcons.check
                    : PocketVisuals.icon(pocket.iconKey),
                background: selected ? Colors.white : PocketVisuals.soft(color),
                color: color,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                pocket.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.style(
                  14,
                  AppText.w800,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
