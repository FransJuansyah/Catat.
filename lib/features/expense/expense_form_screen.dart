import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/providers.dart';
import '../../domain/home_summary.dart';
import '../../domain/pay_period.dart';

/// Layar 11 · Catat Manual. Dengan [editId] berfungsi sebagai form ubah.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({
    super.key,
    this.initialDate,
    this.initialPocketId,
    this.editId,
  });

  final DateTime? initialDate;
  final String? initialPocketId;
  final String? editId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  static const _maxAmount = 99999999999; // 11 digit

  final _title = TextEditingController();
  int _amount = 0;
  late DateTime _date;
  DateTime? _originalTime;
  String? _pocketId;
  bool _saving = false;

  bool get _isEdit => widget.editId != null;

  // Keyboard HP menutupi tombol Simpan; tutup saat user pindah ke keypad/pilihan.
  void _hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void initState() {
    super.initState();
    _date = dateOnly(widget.initialDate ?? ref.read(clockProvider)());
    _pocketId = widget.initialPocketId;
    if (_isEdit) _loadForEdit();
  }

  Future<void> _loadForEdit() async {
    final detail = await ref
        .read(budgetRepositoryProvider)
        .loadExpense(widget.editId!);
    if (detail == null || !mounted) return;
    setState(() {
      _amount = detail.entry.amount;
      _title.text = detail.entry.title;
      _date = dateOnly(detail.entry.occurredAt);
      _originalTime = detail.entry.occurredAt;
      _pocketId = detail.entry.pocket.id;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _press(String key) {
    _hideKeyboard();
    setState(() {
      switch (key) {
        case 'del':
          _amount ~/= 10;
        case '000':
          if (_amount > 0 && _amount * 1000 <= _maxAmount) _amount *= 1000;
        default:
          final next = _amount * 10 + int.parse(key);
          if (next <= _maxAmount) _amount = next;
      }
    });
  }

  Future<void> _pickDate() async {
    _hideKeyboard();
    final today = dateOnly(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
      helpText: 'Tanggal pengeluaran',
    );
    if (picked != null) setState(() => _date = picked);
  }

  DateTime _occurredAt() {
    final now = ref.read(clockProvider)();
    if (_date == dateOnly(now) && !_isEdit) return now;
    final t = _originalTime ?? DateTime(_date.year, _date.month, _date.day, 12);
    return DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    final pocketId = _pocketId;
    if (_amount <= 0 || pocketId == null) return;
    final title = _title.text.trim().isEmpty
        ? 'Pengeluaran'
        : _title.text.trim();
    final repo = ref.read(budgetRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await repo.updateExpense(
          widget.editId!,
          pocketId: pocketId,
          amount: _amount,
          title: title,
          occurredAt: _occurredAt(),
        );
        if (mounted) context.pop();
      } else {
        final id = await repo.addExpense(
          pocketId: pocketId,
          amount: _amount,
          title: title,
          occurredAt: _occurredAt(),
        );
        if (mounted) context.pushReplacement('/tercatat/$id');
      }
    } on StateError {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal itu di luar periode gaji yang tercatat.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pockets =
        ref.watch(homeSummaryProvider).value?.pockets ?? const <PocketView>[];
    final selected = pockets.where((p) => p.id == _pocketId).firstOrNull;
    final caretColor = selected == null ? AppColors.ink : Color(selected.color);
    final today = dateOnly(ref.watch(clockProvider)());

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
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
                      title: _isEdit ? 'Ubah Catatan' : 'Catat Manual',
                      close: true,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Nominal',
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rupiah(_amount),
                            style: AppText.style(
                              44,
                              AppText.w800,
                              color: _amount == 0
                                  ? AppColors.faint
                                  : AppColors.ink,
                              spacingPercent: -3,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(width: 3, height: 40, color: caretColor),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _TitleField(controller: _title)),
                        const SizedBox(width: 8),
                        _DateChip(
                          label: relativeDay(_date, today),
                          onTap: _pickDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (final (i, p) in pockets.indexed) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _PocketChip(
                              pocket: p,
                              selected: p.id == _pocketId,
                              onTap: () {
                                _hideKeyboard();
                                setState(() => _pocketId = p.id);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    _Keypad(
                      onKey: _press,
                      onClear: () => setState(() => _amount = 0),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Simpan',
                      loading: _saving,
                      onPressed: _amount > 0 && _pocketId != null
                          ? _save
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.pencil, size: 16, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              style: AppText.style(15, AppText.w700),
              cursorColor: AppColors.ink,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                counterText: '',
                hintText: 'Buat apa?',
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
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

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
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.calendar,
                  size: 16,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 6),
                Text(label, style: AppText.style(13, AppText.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PocketChip extends StatelessWidget {
  const _PocketChip({
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
      shape: StadiumBorder(
        side: selected
            ? BorderSide.none
            : const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PocketVisuals.icon(pocket.iconKey),
                size: 16,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  pocket.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(
                    13,
                    AppText.w800,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey, required this.onClear});

  final ValueChanged<String> onKey;
  final VoidCallback onClear;

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
                  child: Material(
                    color: AppColors.card,
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
