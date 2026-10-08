import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/icon_picker_sheet.dart';
import '../../core/widgets/pocket_chip.dart';
import '../../data/providers.dart';
import '../../domain/bills.dart';
import '../../domain/expense_icon.dart';
import '../../domain/types.dart';

/// Isian awal tagihan baru, mis. dari chat AI ("Jadikan tagihan").
class BillDraft {
  const BillDraft({
    this.name = '',
    this.amount = 0,
    this.dueDay,
    this.kind = BillKind.cicilan,
    this.remaining,
    this.pocketName,
  });

  final String name;
  final int amount;
  final int? dueDay;
  final BillKind kind;
  final int? remaining;
  final String? pocketName;
}

/// Layar 70 · Tambah tagihan / ubah tagihan ([billId] terisi).
class BillEditScreen extends ConsumerStatefulWidget {
  const BillEditScreen({super.key, this.billId, this.draft});

  final String? billId;
  final BillDraft? draft;

  @override
  ConsumerState<BillEditScreen> createState() => _BillEditScreenState();
}

class _BillEditScreenState extends ConsumerState<BillEditScreen> {
  final _name = TextEditingController();
  final _focus = FocusNode();
  BillKind _kind = BillKind.cicilan;
  int _amount = 0;
  late int _dueDay = ref.read(clockProvider)().day;
  int _remaining = 12;
  String? _pocketId;
  bool _remind = true;
  String _iconKey = 'receipt';
  bool _iconPicked = false;
  bool _loaded = false;
  bool _saving = false;

  bool get _editing => widget.billId != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (!_iconPicked) {
        _iconKey = guessExpenseIcon(_name.text, fallback: 'receipt');
      }
      setState(() {});
    });
    final d = widget.draft;
    if (d != null) {
      _name.text = d.name;
      _amount = d.amount;
      _kind = d.kind;
      if (d.dueDay != null) _dueDay = d.dueDay!.clamp(1, 31);
      if (d.remaining != null) _remaining = d.remaining!.clamp(1, 120);
    }
    if (_editing) _load();
  }

  Future<void> _load() async {
    final b = await ref.read(billRepositoryProvider).loadBill(widget.billId!);
    if (!mounted || b == null) return;
    setState(() {
      _name.text = b.name;
      _iconKey = b.iconKey;
      _iconPicked = true;
      _kind = b.kind;
      _amount = b.amount;
      _dueDay = b.dueDay;
      _remaining = (b.remaining ?? 12).clamp(1, 120);
      _pocketId = b.pocketId;
      _remind = b.remind;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _amount > 0;

  /// "Lunas Mei 2027" untuk cicilan.
  String _lunas() {
    final today = ref.read(clockProvider)();
    final start = firstDueMonth(_dueDay, today);
    return 'Lunas ${monthLabel(start + _remaining - 1)}';
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final repo = ref.read(billRepositoryProvider);
    final pockets = ref.read(homeSummaryProvider).value?.pockets ?? const [];
    final pocketId =
        _pocketId ??
        pockets.where((p) => p.type == PocketType.wajib).firstOrNull?.id;
    if (_editing) {
      await repo.updateBill(
        widget.billId!,
        name: _name.text,
        iconKey: _iconKey,
        amount: _amount,
        dueDay: _dueDay,
        kind: _kind,
        remaining: _remaining,
        pocketId: pocketId,
        remind: _remind,
      );
    } else {
      await repo.addBill(
        name: _name.text,
        iconKey: _iconKey,
        amount: _amount,
        dueDay: _dueDay,
        kind: _kind,
        remaining: _remaining,
        pocketId: pocketId,
        remind: _remind,
      );
    }
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await showConfirmSheet(
      context,
      title: 'Hapus tagihan ini?',
      message: 'Catatan yang udah dibayar tetap ada. Pengingatnya berhenti.',
      confirmLabel: 'Hapus tagihan',
      danger: true,
    );
    if (!ok || !mounted) return;
    await ref.read(billRepositoryProvider).deleteBill(widget.billId!);
    if (mounted) context.pop();
  }

  Future<void> _pickDay() async {
    _focus.unfocus();
    final day = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      builder: (sheet) => SafeArea(
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
                'Bayar tiap tanggal',
                style: AppText.style(20, AppText.w800, spacingPercent: -2),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (var d = 1; d <= 31; d++)
                    Material(
                      color: d == _dueDay ? AppColors.ink : AppColors.track,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(sheet, d),
                        child: Center(
                          child: Text(
                            '$d',
                            style: AppText.style(
                              14,
                              AppText.w800,
                              color: d == _dueDay
                                  ? AppColors.lime
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Tanggal 29–31 jadi hari terakhir di bulan yang lebih pendek.',
                style: AppText.style(12, AppText.w500, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
    if (day != null) setState(() => _dueDay = day);
  }

  @override
  Widget build(BuildContext context) {
    final pockets = ref.watch(homeSummaryProvider).value?.pockets ?? const [];
    _pocketId ??= _editing && !_loaded
        ? null
        : (widget.draft?.pocketName == null
                  ? null
                  : pockets
                        .where((p) => p.name == widget.draft!.pocketName)
                        .firstOrNull
                        ?.id) ??
              pockets.where((p) => p.type == PocketType.wajib).firstOrNull?.id;
    final pocket = pockets.where((p) => p.id == _pocketId).firstOrNull;
    final color = pocket == null ? AppColors.ink : Color(pocket.color);
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
                  AppTopBar(
                    title: _editing ? 'Ubah tagihan' : 'Tambah tagihan',
                    trailingIcon: _editing ? LucideIcons.trash2 : null,
                    trailingColor: AppColors.danger,
                    onTrailing: _editing ? _delete : null,
                  ),
                  const SizedBox(height: 16),
                  SegmentedTabs<BillKind>(
                    items: const [
                      (BillKind.cicilan, 'Cicilan'),
                      (BillKind.rutin, 'Rutin tiap bulan'),
                    ],
                    value: _kind,
                    onChanged: (k) => setState(() => _kind = k),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      _focus.unfocus();
                      final v = await showAmountSheet(
                        context,
                        title: 'Bayar per bulan',
                        initial: _amount,
                      );
                      if (v != null) setState(() => _amount = v);
                    },
                    child: Column(
                      children: [
                        Text(
                          'Bayar per bulan',
                          style: AppText.style(
                            13,
                            AppText.w500,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rupiah(_amount),
                          style: AppText.style(
                            36,
                            AppText.w800,
                            color: _amount > 0
                                ? AppColors.ink
                                : AppColors.faint,
                            spacingPercent: -3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          _focus.unfocus();
                          final k = await showIconPicker(
                            context,
                            selected: _iconKey,
                          );
                          if (k != null) {
                            setState(() {
                              _iconKey = k;
                              _iconPicked = true;
                            });
                          }
                        },
                        child: IconBadge(
                          icon: PocketVisuals.icon(_iconKey),
                          background: color == AppColors.ink
                              ? AppColors.track
                              : PocketVisuals.soft(color),
                          color: color,
                          size: 52,
                          iconSize: 24,
                          square: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(
                              AppRadius.input,
                            ),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.pencil,
                                size: 18,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _name,
                                  focusNode: _focus,
                                  maxLength: 40,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: AppText.style(15, AppText.w700),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    counterText: '',
                                    border: InputBorder.none,
                                    hintText: 'Nama, mis. Cicilan HP',
                                    hintStyle: AppText.style(
                                      15,
                                      AppText.w500,
                                      color: AppColors.faint,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    icon: LucideIcons.calendar,
                    label: 'Bayar tiap tanggal',
                    value: 'Tanggal $_dueDay',
                    onTap: _pickDay,
                  ),
                  if (_kind == BillKind.cicilan) ...[
                    const SizedBox(height: 12),
                    _Field(
                      icon: LucideIcons.repeat,
                      label: 'Sisa berapa kali',
                      value: _lunas(),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StepButton(
                            icon: LucideIcons.minus,
                            onTap: _remaining > 1
                                ? () => setState(() => _remaining--)
                                : null,
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${_remaining}x',
                              textAlign: TextAlign.center,
                              style: AppText.style(16, AppText.w800),
                            ),
                          ),
                          _StepButton(
                            icon: LucideIcons.plus,
                            filled: true,
                            onTap: _remaining < 120
                                ? () => setState(() => _remaining++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Bayar dari kantong',
                    style: AppText.style(
                      13,
                      AppText.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ChipRows(
                    children: [
                      for (final p in pockets)
                        PocketChip(
                          pocket: p,
                          selected: p.id == _pocketId,
                          onTap: () => setState(() => _pocketId = p.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Row(
                      children: [
                        const IconBadge(
                          icon: LucideIcons.bell,
                          background: AppColors.lime,
                          color: AppColors.ink,
                          size: AppSize.badgeSm,
                          iconSize: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ingetin sehari sebelumnya',
                                style: AppText.style(15, AppText.w800),
                              ),
                              Text(
                                'Jam 09:00, lewat notifikasi',
                                style: AppText.style(
                                  12,
                                  AppText.w500,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppToggle(
                          value: _remind,
                          onChanged: (v) => setState(() => _remind = v),
                        ),
                      ],
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
                label: 'Simpan tagihan',
                loading: _saving,
                onPressed: _valid ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.style(
                        12,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(value, style: AppText.style(15, AppText.w800)),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.faint,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.ink : AppColors.track,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 16,
            color: onTap == null
                ? AppColors.faint
                : filled
                ? AppColors.lime
                : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
