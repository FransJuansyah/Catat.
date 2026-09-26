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
import '../../data/providers.dart';
import '../../domain/home_summary.dart';
import '../../domain/types.dart';
import 'pocket_widgets.dart';

const _quick = [50000, 100000, 200000];
const _noteBg = Color(0xFFFFF6DB);
const _noteText = Color(0xFF8A5A00);

/// Layar 25 · Pindahin Saldo Antar Kantong.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key, this.fromId, this.toId});

  final String? fromId;
  final String? toId;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  String? _from;
  String? _to;
  int _amount = 0;
  bool _saving = false;

  /// Isi awal: tujuan dari argumen (atau kantong ke-2), asal = kantong lain
  /// dengan sisa terbesar.
  void _init(List<PocketView> pockets) {
    if (_to != null || pockets.length < 2) return;
    _to = pockets.any((p) => p.id == widget.toId) ? widget.toId : pockets[1].id;
    final others = pockets.where((p) => p.id != _to).toList()
      ..sort((a, b) => b.balance.remaining.compareTo(a.balance.remaining));
    _from = others.any((p) => p.id == widget.fromId)
        ? widget.fromId
        : others.first.id;
  }

  Future<void> _pick({required bool from, required List<PocketView> pockets}) {
    final exclude = from ? _to : _from;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.disabledBg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                from ? 'Ambil dari kantong' : 'Pindahin ke kantong',
                style: AppText.style(17, AppText.w800),
              ),
              const SizedBox(height: 8),
              for (final p in pockets)
                if (p.id != exclude)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconBadge(
                      icon: PocketVisuals.icon(p.iconKey),
                      background: PocketVisuals.soft(Color(p.color)),
                      color: Color(p.color),
                    ),
                    title: Text(p.name, style: AppText.style(15, AppText.w800)),
                    subtitle: Text(
                      'Sisa ${rupiah(p.balance.remaining)}',
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    trailing: p.id == (from ? _from : _to)
                        ? const Icon(LucideIcons.check, color: AppColors.ink)
                        : null,
                    onTap: () {
                      setState(() => from ? _from = p.id : _to = p.id);
                      Navigator.pop(context);
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(PocketView from, PocketView to) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(budgetRepositoryProvider)
          .transferBalance(
            fromPocketId: from.id,
            toPocketId: to.id,
            amount: _amount,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${rupiah(_amount)} dipindah ke ${to.name}')),
      );
      context.pop();
    } on StateError {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saldo ${from.name} nggak cukup.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pockets =
        ref.watch(homeSummaryProvider).value?.pockets ?? const <PocketView>[];
    _init(pockets);
    final from = pockets.where((p) => p.id == _from).firstOrNull;
    final to = pockets.where((p) => p.id == _to).firstOrNull;
    final available = from?.balance.remaining ?? 0;
    final tooMuch = _amount > available;

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
                  const AppTopBar(title: 'Pindahin Saldo'),
                  if (from != null && to != null) ...[
                    const SizedBox(height: 20),
                    _PocketPicker(
                      label: 'Dari',
                      pocket: from,
                      caption: 'Saldo ${rupiah(from.balance.remaining)}',
                      onTap: () => _pick(from: true, pockets: pockets),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Material(
                          color: AppColors.ink,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => setState(() {
                              final t = _from;
                              _from = _to;
                              _to = t;
                            }),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                LucideIcons.arrowDown,
                                size: 18,
                                color: AppColors.lime,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _PocketPicker(
                      label: 'Ke',
                      pocket: to,
                      caption: 'Sisa ${rupiah(to.balance.remaining)}',
                      onTap: () => _pick(from: false, pockets: pockets),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: Text(
                        'Nominal',
                        style: AppText.style(
                          13,
                          AppText.w500,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showAmountSheet(
                          context,
                          title: 'Nominal dipindah',
                          initial: _amount,
                          confirmLabel: 'Pakai',
                        );
                        if (picked != null) setState(() => _amount = picked);
                      },
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            rupiah(_amount),
                            style: AppText.style(
                              40,
                              AppText.w800,
                              color: _amount == 0
                                  ? AppColors.faint
                                  : tooMuch
                                  ? AppColors.danger
                                  : AppColors.ink,
                              spacingPercent: -3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (final q in _quick) ...[
                          Expanded(
                            child: PillChip(
                              label: rupiahShort(q),
                              selected: _amount == q,
                              outlined: true,
                              onTap: q <= available
                                  ? () => setState(() => _amount = q)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: PillChip(
                            label: 'Semua',
                            selected: _amount > 0 && _amount == available,
                            outlined: true,
                            onTap: available > 0
                                ? () => setState(() => _amount = available)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (_amount > 0) ...[
                      const SizedBox(height: 14),
                      _Note(
                        text: tooMuch
                            ? 'Saldo ${from.name} cuma ${rupiah(available)}.'
                            : from.type == PocketType.darurat
                            ? '${from.name} jadi ${rupiah(available - _amount)}. Pakai kalau beneran perlu ya!'
                            : 'Sisa ${from.name} jadi ${rupiah(available - _amount)}.',
                        danger: tooMuch,
                      ),
                    ],
                  ] else if (pockets.isNotEmpty && pockets.length < 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        'Butuh minimal 2 kantong buat pindahin saldo.',
                        textAlign: TextAlign.center,
                        style: AppText.style(
                          14,
                          AppText.w500,
                          color: AppColors.muted,
                        ),
                      ),
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
                label: 'Pindahin',
                loading: _saving,
                onPressed: from != null && to != null && _amount > 0 && !tooMuch
                    ? () => _save(from, to)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PocketPicker extends StatelessWidget {
  const _PocketPicker({
    required this.label,
    required this.pocket,
    required this.caption,
    required this.onTap,
  });

  final String label;
  final PocketView pocket;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(pocket.color);
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.cardLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.style(13, AppText.w700, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconBadge(
                    icon: PocketVisuals.icon(pocket.iconKey),
                    background: PocketVisuals.soft(color),
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pocket.name,
                          style: AppText.style(16, AppText.w800),
                        ),
                        Text(
                          caption,
                          style: AppText.style(
                            13,
                            AppText.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.danger});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : _noteText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: danger ? AppColors.danger.withValues(alpha: 0.1) : _noteBg,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.style(13, AppText.w700, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
