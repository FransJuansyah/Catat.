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
import '../../core/widgets/icon_badge.dart';
import '../../data/providers.dart';
import '../../domain/allocation.dart';
import '../../domain/home_summary.dart';
import '../../domain/pay_period.dart';

/// Layar 30 · Tambah / Ubah Pemasukan. Nominal langsung dibagi ke kantong.
class IncomeFormScreen extends ConsumerStatefulWidget {
  const IncomeFormScreen({
    super.key,
    this.initialDate,
    this.initialAmount,
    this.initialTitle,
    this.initialTime,
    this.editId,
  });

  final DateTime? initialDate;

  /// Ubah pemasukan yang sudah ada (ketuk di Catatan).
  final String? editId;

  /// Isian awal dari notifikasi bank (catat otomatis).
  final int? initialAmount;
  final String? initialTitle;

  /// Waktu transaksi persis (dipakai kalau tanggal tidak diubah).
  final DateTime? initialTime;

  @override
  ConsumerState<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends ConsumerState<IncomeFormScreen> {
  final _title = TextEditingController();
  int _amount = 0;
  late DateTime _date;
  bool _saving = false;

  bool get _isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _date = dateOnly(
      widget.initialTime ?? widget.initialDate ?? ref.read(clockProvider)(),
    );
    _amount = widget.initialAmount ?? 0;
    _title.text = widget.initialTitle ?? '';
    if (_isEdit) _loadForEdit();
  }

  DateTime? _originalTime;

  Future<void> _loadForEdit() async {
    final detail = await ref
        .read(budgetRepositoryProvider)
        .loadIncome(widget.editId!);
    if (detail == null || !mounted) return;
    setState(() {
      _amount = detail.entry.amount;
      _title.text = detail.entry.title;
      _date = dateOnly(detail.entry.occurredAt);
      _originalTime = detail.entry.occurredAt;
    });
  }

  Future<void> _delete() async {
    final ok = await showConfirmSheet(
      context,
      title: 'Hapus pemasukan ini?',
      message:
          '${rupiah(_amount)} dari "${_title.text.trim()}" akan ditarik lagi '
          'dari kantong-kantongmu.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    await ref.read(budgetRepositoryProvider).deleteIncome(widget.editId!);
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _pickDate() async {
    _hideKeyboard();
    final today = dateOnly(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
      helpText: 'Tanggal pemasukan',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_amount <= 0) return;
    final now = ref.read(clockProvider)();
    final original = _originalTime ?? widget.initialTime;
    final when = original != null && _date == dateOnly(original)
        ? original
        : _date == dateOnly(now)
        ? now
        : DateTime(_date.year, _date.month, _date.day, 12);
    final title = _title.text.trim().isEmpty ? 'Pemasukan' : _title.text.trim();
    setState(() => _saving = true);
    try {
      final repo = ref.read(budgetRepositoryProvider);
      if (_isEdit) {
        await repo.updateIncome(
          widget.editId!,
          amount: _amount,
          title: title,
          occurredAt: when,
        );
        if (mounted) context.pop();
        return;
      }
      final id = await repo.addIncome(
        amount: _amount,
        title: title,
        occurredAt: when,
      );
      if (mounted) context.pushReplacement('/pemasukan-masuk/$id');
    } on StateError {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal itu di luar periode yang tercatat.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pockets =
        ref.watch(homeSummaryProvider).value?.pockets ?? const <PocketView>[];
    final parts = splitIncome(_amount, [for (final p in pockets) p.rule]);
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
                      title: _isEdit ? 'Ubah Pemasukan' : 'Tambah Pemasukan',
                      close: true,
                      trailingIcon: _isEdit ? LucideIcons.trash2 : null,
                      onTrailing: _isEdit ? _delete : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Duit masuk',
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
                            '+${rupiah(_amount)}',
                            style: AppText.style(
                              42,
                              AppText.w800,
                              color: _amount == 0
                                  ? AppColors.faint
                                  : AppColors.success,
                              spacingPercent: -3,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 3,
                            height: 38,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                                  size: 16,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _title,
                                    maxLength: 40,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.done,
                                    style: AppText.style(15, AppText.w700),
                                    cursorColor: AppColors.ink,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      counterText: '',
                                      hintText: 'Dari mana? (Ngojek, project…)',
                                      hintStyle: AppText.style(
                                        14,
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
                        const SizedBox(width: 8),
                        Material(
                          color: AppColors.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.input,
                            ),
                            side: const BorderSide(color: AppColors.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _pickDate,
                            child: SizedBox(
                              height: 50,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.calendar,
                                      size: 16,
                                      color: AppColors.ink,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      relativeDay(_date, today),
                                      style: AppText.style(13, AppText.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SplitPreview(pockets: pockets, parts: parts),
                    const Spacer(),
                    const SizedBox(height: 14),
                    AmountKeypad(
                      onKey: (k) {
                        _hideKeyboard();
                        setState(() => _amount = applyAmountKey(_amount, k));
                      },
                      onClear: () => setState(() => _amount = 0),
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: _isEdit ? 'Simpan' : 'Masukin & bagi',
                      loading: _saving,
                      onPressed: _amount > 0 && pockets.isNotEmpty
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

class _SplitPreview extends StatelessWidget {
  const _SplitPreview({required this.pockets, required this.parts});

  final List<PocketView> pockets;
  final Map<String, int> parts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 14,
                color: AppColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                'Langsung dibagi ke kantong',
                style: AppText.style(12, AppText.w700, color: AppColors.muted),
              ),
            ],
          ),
          for (final p in pockets) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                IconBadge(
                  icon: PocketVisuals.icon(p.iconKey),
                  background: PocketVisuals.soft(Color(p.color)),
                  color: Color(p.color),
                  size: 28,
                  iconSize: 14,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.percent > 0 ? '${p.name}  ${p.percent}%' : p.name,
                    style: AppText.style(13, AppText.w700),
                  ),
                ),
                Text(
                  '+${rupiahShort(parts[p.id] ?? 0)}',
                  style: AppText.style(14, AppText.w800, color: Color(p.color)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
