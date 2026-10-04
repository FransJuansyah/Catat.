import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/pocket_chip.dart';
import '../../data/providers.dart';
import '../../data/repositories/budget_repository.dart';
import '../../domain/home_summary.dart';
import '../../domain/pay_period.dart';
import '../../domain/text_note_parser.dart';

/// Layar 60–63 · Catat pakai ketikan. Tab Scan & Manual membuka layar 04 / 11.
class QuickNoteScreen extends ConsumerStatefulWidget {
  const QuickNoteScreen({super.key});

  @override
  ConsumerState<QuickNoteScreen> createState() => _QuickNoteScreenState();
}

const _examples = [
  'kopi susu 25rb',
  'makan siang 35rb pake gopay',
  'Dimas bayar utang 150rb',
  'bayar utang ke Rina 100rb',
  'gajian 6,5jt',
];

/// Catatan hasil baca yang masih bisa diubah sebelum disimpan.
class _Draft {
  _Draft({
    required this.income,
    required this.amount,
    required this.title,
    this.pocketId,
  });

  bool income;
  int amount;
  String title;
  String? pocketId;
}

class _QuickNoteScreenState extends ConsumerState<QuickNoteScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  String? _sent;
  TextNoteResult? _result;
  List<_Draft> _drafts = [];
  int _daysAgo = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<PocketView> get _pockets =>
      ref.read(homeSummaryProvider).value?.pockets ?? const [];

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final result = parseTextNote(text);
    final pockets = _pockets;
    setState(() {
      _sent = text;
      _result = result;
      _drafts = [];
      _daysAgo = 0;
      if (result is TextNotesRead) {
        _daysAgo = result.daysAgo;
        _drafts = [
          for (final n in result.notes)
            _Draft(
              income: n.isIncome,
              amount: n.amount,
              title: n.title,
              pocketId:
                  (pockets.where((p) => p.type == n.pocketType).firstOrNull ??
                          pockets.firstOrNull)
                      ?.id,
            ),
        ];
      }
    });
    _input.clear();
    if (result is TextNotesRead) {
      _focus.unfocus();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _useExample(String text) {
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    _send();
  }

  /// Ketuk gelembung = ketik ulang kalimat tadi.
  void _retype() {
    final text = _sent;
    if (text == null) return;
    setState(() {
      _sent = null;
      _result = null;
      _drafts = [];
    });
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
  }

  DateTime get _today => dateOnly(ref.read(clockProvider)());

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: today.subtract(Duration(days: _daysAgo)),
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(() => _daysAgo = today.difference(dateOnly(picked)).inDays);
    }
  }

  Future<void> _save() async {
    if (_drafts.isEmpty || _saving) return;
    final fallback = _pockets.firstOrNull?.id;
    final notes = [
      for (final d in _drafts)
        d.income
            ? QuickNoteInput.income(amount: d.amount, title: d.title)
            : QuickNoteInput.expense(
                pocketId: d.pocketId ?? fallback!,
                amount: d.amount,
                title: d.title,
              ),
    ];
    final now = ref.read(clockProvider)();
    final day = _today.subtract(Duration(days: _daysAgo));
    final when = DateTime(day.year, day.month, day.day, now.hour, now.minute);
    setState(() => _saving = true);
    try {
      final ids = await ref
          .read(budgetRepositoryProvider)
          .addQuickNotes(notes, occurredAt: when);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (ids.length == 1) {
        context.pushReplacement(
          notes.single.income
              ? '/pemasukan-masuk/${ids.single}'
              : '/tercatat/${ids.single}',
        );
      } else {
        final messenger = ScaffoldMessenger.of(context);
        context.pop();
        messenger.showSnackBar(
          SnackBar(content: Text('${ids.length} catatan tersimpan')),
        );
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

  Future<void> _edit(int index) async {
    final updated = await showModalBottomSheet<_Draft?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.ink.withValues(alpha: 0.55),
      builder: (_) => _EditSheet(
        draft: _drafts[index],
        pockets: _pockets,
        dateLabel: _dateLabel,
        onPickDate: () async {
          Navigator.of(context).pop();
          await _pickDate();
        },
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      if (updated.amount <= 0) {
        _drafts.removeAt(index);
      } else {
        _drafts[index] = updated;
      }
    });
    if (_drafts.isEmpty) _retype();
  }

  String get _dateLabel => switch (_daysAgo) {
    0 => 'Hari ini',
    1 => 'Kemarin',
    _ => shortDate(_today.subtract(Duration(days: _daysAgo))),
  };

  @override
  Widget build(BuildContext context) {
    // Muat kantong lebih awal supaya tebakan kantong langsung ada.
    ref.watch(homeSummaryProvider);
    final read = _result is TextNotesRead && _drafts.isNotEmpty;
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
              const AppTopBar(title: 'Catat', close: true),
              const SizedBox(height: 16),
              SegmentedTabs<int>(
                items: const [(0, 'Ketik'), (1, 'Scan'), (2, 'Manual')],
                value: 0,
                onChanged: (v) {
                  if (v == 1) context.pushReplacement('/scan');
                  if (v == 2) context.pushReplacement('/catat');
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (_sent == null)
                      ..._empty()
                    else ...[
                      _UserBubble(text: _sent!, onTap: _retype),
                      const SizedBox(height: 14),
                      if (read)
                        ..._readBody()
                      else
                        _NotUnderstood(
                          needsAmount: _result is TextNoteNeedsAmount,
                          onExample: _useExample,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (read)
                AppButton(
                  label: 'Simpan ${_drafts.length} catatan',
                  icon: LucideIcons.check,
                  loading: _saving,
                  onPressed: _save,
                )
              else
                _InputBar(controller: _input, focus: _focus, onSend: _send),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _empty() => [
    const SizedBox(height: 18),
    const Center(
      child: IconBadge(
        icon: LucideIcons.sparkles,
        background: AppColors.lime,
        color: AppColors.ink,
        size: 64,
        iconSize: 30,
      ),
    ),
    const SizedBox(height: 12),
    Text(
      'Mau catat apa?',
      textAlign: TextAlign.center,
      style: AppText.style(24, AppText.w800, spacingPercent: -2),
    ),
    const SizedBox(height: 8),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Ketik aja kayak lagi ngobrol. Uang keluar, uang masuk, sekaligus banyak juga bisa.',
        textAlign: TextAlign.center,
        style: AppText.style(14, AppText.w500, color: AppColors.muted),
      ),
    ),
    const SizedBox(height: 22),
    Text(
      'Coba ketik kayak gini',
      style: AppText.style(13, AppText.w700, color: AppColors.muted),
    ),
    const SizedBox(height: 10),
    for (final e in _examples) ...[
      Align(
        alignment: Alignment.centerLeft,
        child: _ExampleChip(text: e, onTap: () => _useExample(e)),
      ),
      const SizedBox(height: 8),
    ],
  ];

  List<Widget> _readBody() {
    final pockets = {for (final p in _pockets) p.id: p};
    final out = _drafts.where((d) => !d.income).fold(0, (s, d) => s + d.amount);
    final inc = _drafts.where((d) => d.income).fold(0, (s, d) => s + d.amount);
    return [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.cardLg),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: LucideIcons.sparkles,
                  background: AppColors.lime,
                  color: AppColors.ink,
                  size: 28,
                  iconSize: 14,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kebaca ${_drafts.length} catatan',
                    style: AppText.style(15, AppText.w800),
                  ),
                ),
                _DatePill(label: _dateLabel, onTap: _pickDate),
              ],
            ),
            const SizedBox(height: 4),
            for (final (i, d) in _drafts.indexed) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.line),
              _DraftRow(
                draft: d,
                pocket: pockets[d.pocketId],
                onTap: () => _edit(i),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _TotalTile(label: 'Keluar', value: rupiah(out)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TotalTile(
              label: 'Masuk',
              value: rupiah(inc),
              color: AppColors.success,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.pencil, size: 14, color: AppColors.muted),
          const SizedBox(width: 8),
          Text(
            'Salah tebak? Ketuk catatannya buat ubah',
            style: AppText.style(13, AppText.w500, color: AppColors.muted),
          ),
        ],
      ),
    ];
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 282),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            text,
            style: AppText.style(15, AppText.w500, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(text, style: AppText.style(14, AppText.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focus,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ready = controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: ready ? AppColors.ink : AppColors.line,
          width: ready ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              minLines: 1,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: AppText.style(15, AppText.w700),
              decoration: InputDecoration(
                isCollapsed: true,
                counterText: '',
                border: InputBorder.none,
                hintText: 'Ketik catatan…',
                hintStyle: AppText.style(
                  15,
                  AppText.w500,
                  color: AppColors.faint,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: ready ? onSend : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ready ? AppColors.ink : AppColors.disabledBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.arrowUp,
                size: 22,
                color: ready ? AppColors.lime : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.calendar, size: 14, color: AppColors.ink),
            const SizedBox(width: 6),
            Text(label, style: AppText.style(12, AppText.w700)),
          ],
        ),
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.draft,
    required this.pocket,
    required this.onTap,
  });

  final _Draft draft;
  final PocketView? pocket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final income = draft.income;
    final color = income
        ? AppColors.success
        : Color(pocket?.color ?? AppColors.ink.toARGB32());
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            IconBadge(
              icon: income
                  ? LucideIcons.arrowDown
                  : PocketVisuals.icon(pocket?.iconKey ?? ''),
              background: PocketVisuals.soft(color),
              color: color,
              size: 40,
              iconSize: 19,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.style(15, AppText.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    income ? 'Uang masuk' : (pocket?.name ?? ''),
                    style: AppText.style(12, AppText.w700, color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${income ? '+' : '-'}${rupiah(draft.amount)}',
              style: AppText.style(
                15,
                AppText.w800,
                color: income ? AppColors.success : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.value,
    this.color = AppColors.ink,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.style(12, AppText.w500, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.style(16, AppText.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Layar 62: bukan catatan uang / nominal tidak ada.
class _NotUnderstood extends StatelessWidget {
  const _NotUnderstood({required this.needsAmount, required this.onExample});

  final bool needsAmount;
  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: LucideIcons.triangleAlert,
                background: Color(0xFFFDECB5),
                color: AppColors.warnIcon,
                size: 32,
                iconSize: 16,
              ),
              const SizedBox(width: 10),
              Text(
                needsAmount ? 'Berapa nominalnya?' : 'Hmm, aku nggak paham',
                style: AppText.style(
                  15,
                  AppText.w800,
                  color: AppColors.warnText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            needsAmount
                ? 'Tulis juga berapa duitnya biar bisa kucatat, misal:'
                : 'Aku cuma bisa bantu catat uang keluar & masuk. Tulis buat apa dan berapa, misal:',
            style: AppText.style(14, AppText.w500, color: AppColors.warnText),
          ),
          const SizedBox(height: 10),
          for (final e in const [
            'makan siang 35rb',
            'Dimas bayar utang 150rb',
          ]) ...[
            _ExampleChip(text: e, onTap: () => onExample(e)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Layar 63: ubah satu catatan sebelum disimpan. Nominal 0 = hapus.
class _EditSheet extends StatefulWidget {
  const _EditSheet({
    required this.draft,
    required this.pockets,
    required this.dateLabel,
    required this.onPickDate,
  });

  final _Draft draft;
  final List<PocketView> pockets;
  final String dateLabel;
  final VoidCallback onPickDate;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late bool _income = widget.draft.income;
  late String? _pocketId = widget.draft.pocketId;
  late final _title = TextEditingController(text: widget.draft.title);
  late final _amount = TextEditingController(text: rupiah(widget.draft.amount));

  int get _amountValue =>
      int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _done({bool delete = false}) {
    Navigator.of(context).pop(
      _Draft(
        income: _income,
        amount: delete ? 0 : _amountValue,
        title: _title.text.trim().isEmpty
            ? (_income ? 'Pemasukan' : 'Pengeluaran')
            : _title.text.trim(),
        pocketId: _pocketId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
              'Ubah catatan',
              style: AppText.style(20, AppText.w800, spacingPercent: -2),
            ),
            const SizedBox(height: 16),
            SegmentedTabs<bool>(
              items: const [(false, 'Uang keluar'), (true, 'Uang masuk')],
              value: _income,
              onChanged: (v) => setState(() => _income = v),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Nominal',
                style: AppText.style(13, AppText.w500, color: AppColors.muted),
              ),
            ),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [_RibuanFormatter()],
              style: AppText.style(36, AppText.w800, spacingPercent: -3),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.input),
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
                            controller: _title,
                            maxLength: 60,
                            style: AppText.style(15, AppText.w700),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: widget.onPickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.calendar,
                          size: 18,
                          color: AppColors.ink,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.dateLabel,
                          style: AppText.style(14, AppText.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (!_income) ...[
              const SizedBox(height: 16),
              Text(
                'Masuk kantong',
                style: AppText.style(13, AppText.w700, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              ChipRows(
                children: [
                  for (final p in widget.pockets)
                    PocketChip(
                      pocket: p,
                      selected: p.id == _pocketId,
                      onTap: () => setState(() => _pocketId = p.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            AppButton(
              label: 'Simpan',
              onPressed: _amountValue > 0 ? _done : null,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => _done(delete: true),
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.danger,
                ),
                label: Text(
                  'Hapus dari daftar',
                  style: AppText.style(
                    14,
                    AppText.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1250000 → "1.250.000" saat diketik.
class _RibuanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue value,
  ) {
    final digits = value.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final number = int.parse(
      digits.length > 12 ? digits.substring(0, 12) : digits,
    );
    final text = rupiah(number);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
