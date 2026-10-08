import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/chat_bubbles.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/progress_track.dart';
import '../../data/chat_assistant.dart';
import '../../data/providers.dart';
import '../../domain/bills.dart';
import '../../domain/chat_reply.dart';
import '../../domain/expense_icon.dart';
import '../../domain/onboard_profile.dart';
import '../../domain/types.dart';

/// Layar 74–75 · Daftar sambil ngobrol: AI menanyakan nama, sumber uang,
/// nominal & jadwal, tagihan rutin, dan uang sekarang, lalu rangkuman.
/// Offline / AI tidak bisa → formulir biasa (layar 27 dst.).
class AiOnboardingScreen extends ConsumerStatefulWidget {
  const AiOnboardingScreen({super.key});

  @override
  ConsumerState<AiOnboardingScreen> createState() => _AiOnboardingScreenState();
}

const _greeting =
    'Halo! Aku yang bantu siapin catat. kamu. Mau dipanggil siapa?';

/// Pesan di layar: dari user, dari bot (dengan pilihan cepat), atau peringatan.
class _Msg {
  const _Msg.user(this.text) : fromUser = true, warn = false, chips = const [];
  const _Msg.bot(this.text, {this.chips = const [], this.warn = false})
    : fromUser = false;

  final bool fromUser;
  final String text;
  final List<String> chips;
  final bool warn;
}

class _AiOnboardingScreenState extends ConsumerState<AiOnboardingScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _msgs = <_Msg>[const _Msg.bot(_greeting)];
  final _turns = <ChatTurn>[const ChatTurn.bot(_greeting)];
  OnboardProfile _profile = const OnboardProfile();
  int _step = 1;
  bool _done = false;
  bool _thinking = false;
  bool _saving = false;

  /// AI tidak bisa dipakai (offline / login tamu mati) → ajak isi formulir.
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _prepare();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final ai = ref.read(chatAssistantProvider);
    final ok = await ai.isOnline() && await ai.ensureSession();
    if (!mounted || ok) return;
    setState(() {
      _unavailable = true;
      _msgs.add(
        const _Msg.bot(
          'Lagi nggak bisa ngobrol (internet mati atau server sibuk). Daftar '
          'pakai formulir aja ya, cuma 5 langkah.',
          warn: true,
        ),
      );
    });
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send([String? chip]) async {
    final text = (chip ?? _input.text).trim();
    if (text.isEmpty || _thinking || _unavailable) return;
    _input.clear();
    _turns.add(ChatTurn.user(text));
    // Jawaban pertama = nama: disimpan di HP, tidak perlu AI (AI kadang
    // menanyakan nama lagi).
    if (_turns.length == 2 && _profile.name.isEmpty) {
      final name = nameFromAnswer(text);
      final ask = 'Hai $name! Uang kamu biasanya dari mana?';
      _turns.add(ChatTurn.bot(ask));
      setState(() {
        _msgs
          ..add(_Msg.user(text))
          ..add(
            _Msg.bot(
              ask,
              chips: const ['Gaji bulanan', 'Uang jajan', 'Nggak tentu'],
            ),
          );
        _profile = OnboardProfile(name: name);
        _step = 2;
      });
      _scrollDown();
      return;
    }
    setState(() {
      _msgs.add(_Msg.user(text));
      _thinking = true;
    });
    _scrollDown();
    final outcome = await ref
        .read(chatAssistantProvider)
        .onboard(turns: List.of(_turns), today: ref.read(clockProvider)());
    if (!mounted) return;
    setState(() {
      _thinking = false;
      switch (outcome) {
        case OnboardAnswered(:final reply):
          _turns.add(ChatTurn.bot(reply.reply));
          _profile = reply.profile.over(_profile);
          _step = reply.step < _step && !reply.finished ? _step : reply.step;
          _done = reply.finished && _profile.complete;
          _msgs.add(
            _Msg.bot(
              reply.reply,
              chips: _done ? const [] : reply.chips,
              warn: reply.offTopic,
            ),
          );
        case OnboardProblem(:final problem):
          // Pesan user tetap di layar; gilirannya dibuang supaya bisa dikirim ulang.
          _turns.removeLast();
          _msgs.add(
            _Msg.bot(switch (problem) {
              ChatOffline() =>
                'Sinyalnya putus. Coba kirim lagi, atau isi formulir aja.',
              ChatLimit() =>
                'Lagi rame banget nih. Isi formulir aja ya, sama cepetnya.',
              _ =>
                'Aku lagi gangguan. Coba lagi bentar, atau isi formulir aja.',
            }, warn: true),
          );
      }
    });
    _scrollDown();
  }

  /// Simpan semuanya seperti formulir (layar 27–42), plus nama & tagihan.
  Future<void> _finish() async {
    final p = _profile;
    if (!p.complete || _saving) return;
    setState(() => _saving = true);
    final ob = ref.read(onboardingProvider.notifier);
    ob.setMode(p.mode!);
    ob.setTemplate(p.pocketTemplate);
    ob.setAmount(p.amount);
    ob.setFrequency(p.cycle);
    if (p.payday > 0) ob.setPayday(p.payday);
    if (p.weekday > 0) ob.setWeekday(p.weekday);
    if (p.estimate > 0) ob.setMonthlyEstimate(p.estimate);
    try {
      await ob.finish(opening: p.balance);
      await ref.read(budgetRepositoryProvider).setUserName(p.name);
      final bills = ref.read(billRepositoryProvider);
      final pockets = await ref
          .read(budgetRepositoryProvider)
          .loadPocketSetup();
      final wajib = pockets.pockets
          .where((x) => x.type == PocketType.wajib)
          .firstOrNull
          ?.id;
      for (final b in p.bills) {
        await bills.addBill(
          name: b.name,
          iconKey: guessExpenseIcon(b.name, fallback: 'receipt'),
          amount: b.amount,
          dueDay: b.dueDay,
          kind: b.remaining == null ? BillKind.rutin : BillKind.cicilan,
          remaining: b.remaining,
          pocketId: wajib,
        );
      }
      if (!mounted) return;
      context.go(
        Uri(
          path: '/privasi-awal',
          queryParameters: {'next': '/beranda'},
        ).toString(),
      );
    } on StateError {
      // Sudah terdaftar (onboarding terbuka lagi) → data lama dipertahankan.
      if (mounted) context.go('/beranda');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi ya.')),
      );
    }
  }

  void _toForm() => context.push('/sumber-uang');

  @override
  Widget build(BuildContext context) {
    final step = _done ? 5 : _step;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'catat.',
                    style: AppText.style(22, AppText.w800, spacingPercent: -3),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toForm,
                    child: Text(
                      'Isi formulir aja',
                      style: AppText.style(
                        13,
                        AppText.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Langkah $step dari 5',
                style: AppText.style(12, AppText.w700, color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              ProgressTrack(
                value: step / 5,
                color: AppColors.ink,
                track: AppColors.line,
                height: 6,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final (i, m) in _msgs.indexed) ...[
                      if (m.fromUser)
                        ChatUserBubble(text: m.text)
                      else
                        ChatBotBubble(
                          text: m.text,
                          warn: m.warn,
                          action: _unavailable && i == _msgs.length - 1
                              ? 'Isi formulir'
                              : null,
                          onAction: _toForm,
                        ),
                      if (m.chips.isNotEmpty && i == _msgs.length - 1) ...[
                        const SizedBox(height: 10),
                        _Chips(chips: m.chips, onTap: _send),
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (_thinking) ...[
                      const ChatBotBubble.typing(),
                      const SizedBox(height: 12),
                    ],
                    if (_done) ...[
                      _Summary(profile: _profile),
                      const SizedBox(height: 12),
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
                              'Mau ubah? Bilang aja, misal "gajinya 7jt"',
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
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!_unavailable)
                ChatInputBar(
                  controller: _input,
                  focus: _focus,
                  onSend: _send,
                  hint: _done ? 'Ada yang mau diubah?' : 'Jawab di sini…',
                ),
              if (_done) ...[
                const SizedBox(height: 10),
                AppButton(
                  label: 'Mulai pakai catat.',
                  loading: _saving,
                  onPressed: _finish,
                ),
              ],
              if (_unavailable)
                AppButton(label: 'Isi formulir', onPressed: _toForm),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pilihan jawaban cepat di bawah pertanyaan bot (mis. "Gaji bulanan").
class _Chips extends StatelessWidget {
  const _Chips({required this.chips, required this.onTap});

  final List<String> chips;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 36),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in chips)
            Material(
              color: AppColors.card,
              shape: const StadiumBorder(
                side: BorderSide(color: AppColors.ink),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onTap(c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Text(c, style: AppText.style(14, AppText.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Layar 75: rangkuman obrolan sebelum mulai.
class _Summary extends ConsumerWidget {
  const _Summary({required this.profile});

  final OnboardProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final today = ref.watch(clockProvider)();
    final income = switch (p.mode) {
      IncomeMode.salary =>
        'Gaji ${rupiahShort(p.amount)} · tgl ${p.payday > 0 ? p.payday : 25}',
      IncomeMode.allowance =>
        'Jajan ${rupiahShort(p.amount)} / ${switch (p.cycle) {
          IncomeFrequency.daily => 'hari',
          IncomeFrequency.weekly => 'minggu',
          IncomeFrequency.monthly => 'bulan',
        }}',
      IncomeMode.irregular =>
        p.estimate > 0
            ? 'Nggak tentu · ±${rupiahShort(p.estimate)}/bln'
            : 'Nggak tentu',
      null => '-',
    };
    Widget kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            k,
            style: AppText.style(14, AppText.w500, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: AppText.style(14, AppText.w700),
            ),
          ),
        ],
      ),
    );
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        t,
        style: AppText.style(13, AppText.w700, color: AppColors.muted),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kv('Nama', p.name),
          kv('Uang masuk', income),
          kv('Uang sekarang', rupiah(p.balance)),
          const SizedBox(height: 4),
          const Divider(height: 1, color: AppColors.line),
          label('Kantong'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in p.pocketTemplate.pockets)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: PocketVisuals.soft(Color(s.color)),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PocketVisuals.icon(s.iconKey),
                        size: 13,
                        color: Color(s.color),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${s.name} ${s.percent}%',
                        style: AppText.style(
                          12,
                          AppText.w800,
                          color: Color(s.color),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (p.bills.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.line),
            label('Tagihan rutin'),
            for (final b in p.bills) _billRow(b, today),
          ],
        ],
      ),
    );
  }

  Widget _billRow(AiBill b, DateTime today) {
    final sub = b.remaining == null
        ? 'Tgl ${b.dueDay} · tiap bulan'
        : 'Tgl ${b.dueDay} · sisa ${b.remaining}x';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconBadge(
            icon: PocketVisuals.icon(
              guessExpenseIcon(b.name, fallback: 'receipt'),
            ),
            background: AppColors.track,
            color: AppColors.ink,
            size: 42,
            iconSize: 20,
            square: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name, style: AppText.style(15, AppText.w800)),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: AppText.style(
                    12,
                    AppText.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(rupiah(b.amount), style: AppText.style(15, AppText.w800)),
        ],
      ),
    );
  }
}
