import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/pocket_chip.dart';
import '../../data/providers.dart';
import '../../domain/pocket_config.dart';
import '../../domain/templates.dart';
import '../../domain/types.dart';

const _maxName = 20;

/// Layar 21 · Edit Kantong (nama, ikon, warna, jenis) + hapus (layar 45).
/// Perubahan masuk ke draft Atur Kantong (layar 20) / Bikin Sendiri (43) dan
/// baru tersimpan saat "Simpan" di sana.
class PocketEditScreen extends ConsumerStatefulWidget {
  const PocketEditScreen({super.key, required this.pocketId});

  final String pocketId;

  @override
  ConsumerState<PocketEditScreen> createState() => _PocketEditScreenState();
}

class _PocketEditScreenState extends ConsumerState<PocketEditScreen> {
  final _name = TextEditingController();
  final _focus = FocusNode();
  String? _iconKey;
  int? _color;
  PocketType? _type;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Isi awal dari draft (sekali, saat draft sudah termuat).
  void _init(PocketConfig p) {
    if (_iconKey != null) return;
    _iconKey = p.iconKey;
    _color = p.color;
    _type = p.type;
    _name.text = p.name;
  }

  void _applyToDraft(PocketConfig p) {
    final name = _name.text.trim();
    ref
        .read(pocketDraftProvider.notifier)
        .updatePocket(
          p.copyWith(
            type: _type,
            name: name.isEmpty ? null : name,
            iconKey: _iconKey,
            color: _color,
          ),
        );
  }

  void _save(PocketConfig p) {
    _applyToDraft(p);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(pocketDraftProvider).value;
    final pocket = draft?.current.pockets
        .where((p) => p.id == widget.pocketId)
        .firstOrNull;
    if (pocket != null) _init(pocket);

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => _focus.unfocus(),
          behavior: HitTestBehavior.translucent,
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
                      title: 'Edit Kantong',
                      trailingIcon: LucideIcons.trash2,
                      trailingColor: AppColors.danger,
                      onTrailing:
                          pocket != null &&
                              draft != null &&
                              draft.current.canRemove
                          ? () => _confirmRemove(pocket, draft)
                          : null,
                    ),
                    if (pocket != null && draft != null) ...[
                      const SizedBox(height: 20),
                      _preview(pocket),
                      const SizedBox(height: 18),
                      _label('Nama kantong'),
                      _nameField(),
                      const SizedBox(height: 18),
                      _label('Ikon'),
                      _iconGrid(Color(_color!)),
                      const SizedBox(height: 18),
                      _label('Warna'),
                      _colorRow(),
                      const SizedBox(height: 18),
                      _label('Jenis'),
                      _typeRow(),
                      const SizedBox(height: 18),
                      _budgetRow(pocket, draft.current),
                    ],
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
                  label: 'Simpan kantong',
                  onPressed: pocket != null && _name.text.trim().isNotEmpty
                      ? () => _save(pocket)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: AppText.style(13, AppText.w700, color: AppColors.muted),
    ),
  );

  Widget _preview(PocketConfig pocket) {
    final color = Color(_color!);
    final name = _name.text.trim();
    return Container(
      padding: const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
      ),
      child: Row(
        children: [
          IconBadge(
            icon: PocketVisuals.icon(_iconKey!),
            background: PocketVisuals.soft(color),
            color: color,
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Nama kantong' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(
                    18,
                    AppText.w800,
                    color: name.isEmpty ? AppColors.faint : AppColors.ink,
                    spacingPercent: -1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pocketTypeLabel(_type!),
                  style: AppText.style(13, AppText.w700, color: color),
                ),
              ],
            ),
          ),
          Text(
            'Preview',
            style: AppText.style(11, AppText.w700, color: AppColors.faint),
          ),
        ],
      ),
    );
  }

  Widget _nameField() {
    final focused = _focus.hasFocus;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: focused ? AppColors.ink : AppColors.line,
          width: focused ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _name,
              focusNode: _focus,
              maxLength: _maxName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: AppText.style(16, AppText.w700),
              cursorColor: Color(_color!),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                counterText: '',
                hintText: 'Mis. Healing & Jajan',
                hintStyle: AppText.style(
                  15,
                  AppText.w500,
                  color: AppColors.faint,
                ),
              ),
            ),
          ),
          Text(
            '${_name.text.length}/$_maxName',
            style: AppText.style(12, AppText.w500, color: AppColors.faint),
          ),
        ],
      ),
    );
  }

  Widget _iconGrid(Color color) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.55,
      children: [
        for (final key in pocketIconChoices)
          Material(
            color: key == _iconKey ? PocketVisuals.soft(color) : AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              side: key == _iconKey
                  ? BorderSide(color: color, width: 2)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                _focus.unfocus();
                setState(() => _iconKey = key);
              },
              child: Icon(
                PocketVisuals.icon(key),
                size: 22,
                color: key == _iconKey ? color : AppColors.ink,
              ),
            ),
          ),
      ],
    );
  }

  Widget _colorRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final c in PocketVisuals.palette)
          GestureDetector(
            onTap: () {
              _focus.unfocus();
              setState(() => _color = c.toARGB32());
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                boxShadow: c.toARGB32() == _color
                    ? [
                        BoxShadow(
                          color: c.withValues(alpha: 0.4),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: c.toARGB32() == _color
                  ? const Icon(LucideIcons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }

  /// Jenis dipakai buat tebak kantong saat scan, peringatan dana darurat &
  /// laporan.
  Widget _typeRow() {
    return Row(
      children: [
        for (final (i, t) in PocketType.values.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: PocketChip.raw(
              label: pocketTypeLabel(t),
              icon: PocketVisuals.typeIcon(t),
              color: PocketVisuals.typeColor(t),
              selected: t == _type,
              onTap: () {
                _focus.unfocus();
                setState(() => _type = t);
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Layar 45: pilih kantong tujuan sisa saldo & catatan, lalu hapus.
  Future<void> _confirmRemove(PocketConfig pocket, PocketDraft draft) async {
    _focus.unfocus();
    final others = [
      for (final p in draft.current.pockets)
        if (p.id != pocket.id) p,
    ];
    final usage = draft.isNew(pocket.id)
        ? null
        : await ref.read(budgetRepositoryProvider).pocketUsage(pocket.id);
    if (!mounted) return;
    final name = _name.text.trim().isEmpty ? pocket.name : _name.text.trim();
    final target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      builder: (_) => _RemoveSheet(
        name: name,
        others: others,
        usage: usage,
        // Bawaan: kantong sejenis, kalau tidak ada kantong pertama.
        initial:
            (others.where((p) => p.type == pocket.type).firstOrNull ??
                    others.first)
                .id,
      ),
    );
    if (target == null || !mounted) return;
    ref.read(pocketDraftProvider.notifier).removePocket(pocket.id, target);
    context.pop();
  }

  Widget _budgetRow(PocketConfig pocket, PocketSetup setup) {
    final pct = pocket.percentOf(setup.base);
    final sub = setup.isRunning
        ? '$pct% dari tiap duit masuk'
        : '$pct% · ${rupiah(pocket.amountOf(setup.base))}';
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _focus.unfocus();
          // Nama/ikon/warna ikut ke layar 22 (judul & warna slider).
          _applyToDraft(pocket);
          context.push('/jatah-kantong/${pocket.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.cardPad),
          child: Row(
            children: [
              const IconBadge(
                icon: LucideIcons.wallet,
                background: AppColors.bg,
                color: AppColors.ink,
                size: 40,
                square: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setup.isRunning ? 'Jatah' : 'Jatah & rentang',
                      style: AppText.style(15, AppText.w800),
                    ),
                    Text(
                      sub,
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

/// Bottom sheet layar 45 · Hapus Kantong. Mengembalikan id kantong tujuan.
class _RemoveSheet extends StatefulWidget {
  const _RemoveSheet({
    required this.name,
    required this.others,
    required this.usage,
    required this.initial,
  });

  final String name;
  final List<PocketConfig> others;

  /// null = kantong belum tersimpan (belum punya saldo & catatan).
  final ({int remaining, int entries})? usage;
  final String initial;

  @override
  State<_RemoveSheet> createState() => _RemoveSheetState();
}

class _RemoveSheetState extends State<_RemoveSheet> {
  late String _target = widget.initial;

  String get _message {
    final u = widget.usage;
    if (u == null || (u.remaining == 0 && u.entries == 0)) {
      return 'Jatahnya dipindah ke:';
    }
    final parts = [
      if (u.remaining != 0) 'Sisa ${rupiah(u.remaining)}',
      if (u.entries > 0) '${u.entries} catatannya',
    ];
    return '${parts.join(' & ')} dipindah ke:';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.disabledBg,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            IconBadge(
              icon: LucideIcons.trash2,
              background: AppColors.danger.withValues(alpha: 0.1),
              color: AppColors.danger,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              'Hapus ${widget.name}?',
              textAlign: TextAlign.center,
              style: AppText.style(22, AppText.w800, spacingPercent: -2),
            ),
            const SizedBox(height: 6),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: AppText.style(14, AppText.w500, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            ChipRows(
              perRow: widget.others.length == 4 ? 2 : 3,
              children: [
                for (final p in widget.others)
                  PocketChip.raw(
                    label: p.name,
                    icon: PocketVisuals.icon(p.iconKey),
                    color: Color(p.color),
                    selected: p.id == _target,
                    onTap: () => setState(() => _target = p.id),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Hapus & pindahin',
              icon: LucideIcons.trash2,
              style: AppButtonStyle.danger,
              onPressed: () => Navigator.pop(context, _target),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Batal',
              style: AppButtonStyle.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
