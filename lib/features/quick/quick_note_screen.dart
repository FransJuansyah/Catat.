import 'dart:async';
import 'dart:math' as math;

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
import '../../data/chat_assistant.dart';
import '../../data/providers.dart';
import '../../data/repositories/budget_repository.dart';
import '../../domain/chat_reply.dart';
import '../../domain/home_summary.dart';
import '../../domain/pay_period.dart';
import '../../domain/pocket_guess.dart';
import '../../domain/receipt_parser.dart';
import '../../domain/text_note_parser.dart';
import '../../domain/types.dart';

/// Layar 60–67 · Catat pakai ketikan. Kalimat jelas dibaca di HP (gratis,
/// offline); kalau tidak jelas, chat AI (catat. Pro, butuh internet) bertanya
/// balik. Tab Scan & Manual membuka layar 04 / 11.
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

/// Isi percakapan, urut tampil.
sealed class _Item {
  const _Item();
}

class _UserMsg extends _Item {
  const _UserMsg(this.text);
  final String text;
}

class _BotMsg extends _Item {
  const _BotMsg(
    this.text, {
    this.warn = false,
    this.icon,
    this.action,
    this.onAction,
  });
  final String text;
  final IconData? icon;

  /// Peringatan (offline, ditolak, jatah habis): latar kuning.
  final bool warn;
  final String? action;
  final VoidCallback? onAction;
}

/// Pengenal di HP tidak paham & chat AI tidak dipakai (bukan Pro).
class _LocalFail extends _Item {
  const _LocalFail({required this.needsAmount});
  final bool needsAmount;
}

class _QuickNoteScreenState extends ConsumerState<QuickNoteScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _log = <_Item>[];

  /// Obrolan dengan AI yang sedang berjalan (bot sedang bertanya balik).
  final _aiTurns = <ChatTurn>[];
  List<_Draft> _drafts = [];
  int _daysAgo = 0;
  bool _saving = false;
  bool _thinking = false;
  bool? _online;
  Timer? _recheck;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _checkOnline();
  }

  /// Cek internet; selama offline dicek ulang tiap beberapa detik supaya
  /// banner hilang sendiri begitu koneksi balik.
  Future<void> _checkOnline() async {
    final online = await ref.read(chatAssistantProvider).isOnline();
    if (!mounted) return;
    setState(() => _online = online);
    _recheck?.cancel();
    if (!online) {
      _recheck = Timer(const Duration(seconds: 5), _checkOnline);
    }
  }

  @override
  void dispose() {
    _recheck?.cancel();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<PocketView> get _pockets =>
      ref.read(homeSummaryProvider).value?.pockets ?? const [];

  bool get _pro => ref.read(proStatusProvider).value?.unlocked ?? false;

  /// Kantong tebakan: nama/ikon kantong dulu, baru jenisnya.
  String? _pocketIdFor(String title, PocketType type) =>
      guessPocket(title, type, _pockets)?.id;

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _log.add(_UserMsg(text));
      _drafts = [];
    });
    _scrollDown();

    // 1. Kalimat jelas dibaca di HP dulu (gratis, jalan tanpa internet).
    //    Kalau bot sedang bertanya balik, jawabannya dikirim ke AI supaya
    //    nyambung dengan pertanyaan tadi.
    if (_aiTurns.isEmpty) {
      final local = parseTextNote(text);
      if (local is TextNotesRead) {
        setState(() {
          _daysAgo = local.daysAgo;
          _drafts = [
            for (final n in local.notes)
              _Draft(
                income: n.isIncome,
                amount: n.amount,
                title: n.title,
                pocketId: _pocketIdFor(n.title, n.pocketType),
              ),
          ];
        });
        _focus.unfocus();
        _scrollDown();
        return;
      }
      if (!_pro) {
        HapticFeedback.lightImpact();
        setState(
          () => _log.add(_LocalFail(needsAmount: local is TextNoteNeedsAmount)),
        );
        _scrollDown();
        return;
      }
    }

    // 2. Chat AI (catat. Pro): bertanya balik / mencatat / menolak.
    final turns = [..._aiTurns, ChatTurn.user(text)];
    setState(() => _thinking = true);
    _scrollDown();
    final outcome = await ref
        .read(chatAssistantProvider)
        .send(
          turns: turns,
          pockets: _pockets,
          today: dateOnly(ref.read(clockProvider)()),
        );
    if (!mounted) return;
    setState(() {
      _thinking = false;
      _aiTurns.clear();
      switch (outcome) {
        case ChatAnswered(:final reply):
          _online = true;
          _recheck?.cancel();
          _onReply(reply, turns);
        case ChatOffline():
          _online = false;
          _recheck?.cancel();
          _recheck = Timer(const Duration(seconds: 5), _checkOnline);
          _log.add(
            _BotMsg(
              'Nggak ada koneksi. Chat AI butuh internet buat nanya balik. '
              'Tulis lengkap aja, misal "kopi 25rb", atau pakai Manual.',
              warn: true,
              icon: LucideIcons.wifiOff,
              action: 'Pakai Manual',
              onAction: () => context.pushReplacement('/catat'),
            ),
          );
        case ChatNeedsLogin():
          _log.add(
            _BotMsg(
              'Chat AI butuh akun biar jatah hariannya kecatat. Masuk dulu ya.',
              warn: true,
              action: 'Masuk akun',
              onAction: () => context.push('/masuk-email'),
            ),
          );
        case ChatLimit(:final limit):
          _log.add(
            _BotMsg(
              'Jatah chat AI hari ini udah habis ($limit pesan). Besok bisa '
              'lagi. Sementara tulis lengkap aja, misal "kopi 25rb".',
              warn: true,
            ),
          );
        case ChatFailed():
          _log.add(
            const _BotMsg(
              'Chat AI lagi gangguan. Coba lagi bentar, atau tulis lengkap '
              'kayak "kopi 25rb".',
              warn: true,
            ),
          );
      }
    });
    if (_drafts.isNotEmpty) _focus.unfocus();
    _scrollDown();
  }

  void _onReply(AssistantReply reply, List<ChatTurn> turns) {
    switch (reply.action) {
      case ChatAction.tanya:
        _aiTurns.addAll([...turns, ChatTurn.bot(reply.reply)]);
        _log.add(_BotMsg(reply.reply));
      case ChatAction.tolak:
        _log.add(_BotMsg(reply.reply, warn: true));
      case ChatAction.catat:
        final byName = {for (final p in _pockets) p.name: p.id};
        _daysAgo = reply.notes.first.daysAgo;
        _drafts = [
          for (final n in reply.notes)
            _Draft(
              income: n.income,
              amount: n.amount,
              title: n.title,
              pocketId: n.income
                  ? null
                  : byName[n.pocketName] ??
                        _pocketIdFor(
                          n.title,
                          guessPocketType(ReceiptData(text: n.title)),
                        ),
            ),
        ];
        // Kalimat tetap: catatan baru tersimpan setelah user ketuk Simpan,
        // jangan sampai AI bilang "sudah masuk".
        _log.add(const _BotMsg('Siap, cek dulu ya. Udah pas? Ketuk Simpan.'));
    }
  }

  void _useExample(String text) {
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    _send();
  }

  /// Mulai lagi; [text] (kalimat terakhir) dikembalikan ke kotak ketik.
  void _restart([String? text]) {
    setState(() {
      _log.clear();
      _aiTurns.clear();
      _drafts = [];
    });
    if (text != null) {
      _input.text = text;
      _input.selection = TextSelection.collapsed(offset: text.length);
      _focus.requestFocus();
    }
  }

  String? get _lastUserText => _log.whereType<_UserMsg>().lastOrNull?.text;

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
    if (_drafts.isEmpty) _restart(_lastUserText);
  }

  String get _dateLabel => switch (_daysAgo) {
    0 => 'Hari ini',
    1 => 'Kemarin',
    _ => shortDate(_today.subtract(Duration(days: _daysAgo))),
  };

  @override
  Widget build(BuildContext context) {
    // Muat kantong & status Pro lebih awal.
    ref.watch(homeSummaryProvider);
    final pro = ref.watch(proStatusProvider).value?.unlocked ?? false;
    final read = _drafts.isNotEmpty;
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
              if (pro && _online == false) ...[
                const SizedBox(height: 12),
                const _OfflineBanner(),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.zero,
                  children: [
                    if (_log.isEmpty && !read)
                      ..._empty()
                    else ...[
                      for (final item in _log) ...[
                        switch (item) {
                          _UserMsg(:final text) => _UserBubble(
                            text: text,
                            onTap: read || _thinking
                                ? null
                                : () => _restart(text),
                          ),
                          _BotMsg() => _BotBubble(message: item),
                          _LocalFail(:final needsAmount) => _NotUnderstood(
                            needsAmount: needsAmount,
                            onExample: _useExample,
                            onPro: () => context.push('/pro'),
                          ),
                        },
                        const SizedBox(height: 12),
                      ],
                      if (_thinking) ...[
                        const _BotBubble(message: _BotMsg(''), typing: true),
                        const SizedBox(height: 12),
                      ],
                      if (read) ..._readBody(),
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
                _InputBar(
                  controller: _input,
                  focus: _focus,
                  onSend: _send,
                  hint: _aiTurns.isNotEmpty ? 'Jawab di sini…' : null,
                ),
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
  const _UserBubble({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

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
    this.hint,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;
  final String? hint;

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
                hintText: hint ?? 'Ketik catatan…',
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
  const _NotUnderstood({
    required this.needsAmount,
    required this.onExample,
    this.onPro,
  });

  final bool needsAmount;
  final ValueChanged<String> onExample;

  /// Bukan Pro: ajak buka Pro supaya chat AI bisa bertanya balik (layar 67).
  final VoidCallback? onPro;

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
          if (onPro != null) ...[
            const SizedBox(height: 4),
            Material(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadius.input),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPro,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const IconBadge(
                        icon: LucideIcons.sparkles,
                        background: AppColors.lime,
                        color: AppColors.ink,
                        size: 32,
                        iconSize: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mau dibantu tanya balik kayak ngobrol? Buka catat. Pro',
                          style: AppText.style(
                            13,
                            AppText.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: AppColors.lime,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Gelembung bot (layar 65–66): avatar lime di kiri, latar putih; kuning untuk
/// peringatan (offline, ditolak, jatah habis).
class _BotBubble extends StatelessWidget {
  const _BotBubble({required this.message, this.typing = false});

  final _BotMsg message;

  /// Titik-titik "lagi ngetik" saat menunggu AI.
  final bool typing;

  @override
  Widget build(BuildContext context) {
    final warn = message.warn;
    final fg = warn ? AppColors.warnText : AppColors.ink;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon:
                message.icon ??
                (warn ? LucideIcons.triangleAlert : LucideIcons.sparkles),
            background: warn ? const Color(0xFFFDECB5) : AppColors.lime,
            color: warn ? AppColors.warnIcon : AppColors.ink,
            size: 28,
            iconSize: 14,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 282),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: warn ? AppColors.warnBg : AppColors.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (typing)
                    const _TypingDots()
                  else
                    Text(
                      message.text,
                      style: AppText.style(15, AppText.w500, color: fg),
                    ),
                  if (message.action != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: message.onAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          message.action!,
                          style: AppText.style(
                            13,
                            AppText.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiga titik yang naik bergantian, seolah bot lagi ngetik.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              _dot(i),
            ],
          ],
        ),
      ),
    );
  }

  /// Titik ke-[i] naik di sepertiga putarannya sendiri, lalu turun lagi.
  Widget _dot(int i) {
    final t = (_anim.value - i * 0.18) % 1.0;
    final lift = t < 0.36 ? math.sin(t / 0.36 * math.pi) : 0.0;
    return Transform.translate(
      offset: Offset(0, -5 * lift),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.muted, AppColors.ink, lift),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Layar 66: dibuka tanpa internet (Pro) — chat AI tidak aktif.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.wifiOff, size: 18, color: AppColors.warnIcon),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Lagi offline. ',
                    style: AppText.style(
                      13,
                      AppText.w800,
                      color: AppColors.warnText,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'Chat AI butuh internet buat nanya balik. Kalimat '
                        'lengkap kayak "kopi 25rb" tetap bisa kecatat.',
                  ),
                ],
              ),
              style: AppText.style(13, AppText.w500, color: AppColors.warnText),
            ),
          ),
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
