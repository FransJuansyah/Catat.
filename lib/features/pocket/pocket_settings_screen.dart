import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/providers.dart';
import '../../domain/pocket_config.dart';
import '../../domain/types.dart';

/// Salmon untuk angka/label "lebih" di kartu gelap (layar 23).
const _warn = Color(0xFFFF8A80);

/// Layar 20 · Atur Kantong (+ layar 23 saat alokasi belum pas). Saat masih
/// daftar jadi layar 43 · Bikin Kantong Sendiri: hasilnya dipakai onboarding
/// lalu lanjut ke 42 (saldo awal).
class PocketSettingsScreen extends ConsumerStatefulWidget {
  const PocketSettingsScreen({super.key});

  @override
  ConsumerState<PocketSettingsScreen> createState() =>
      _PocketSettingsScreenState();
}

class _PocketSettingsScreenState extends ConsumerState<PocketSettingsScreen> {
  bool _saving = false;

  Future<void> _save(PocketDraft draft) async {
    if (!draft.dirty && !draft.onboarding) {
      context.pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(pocketDraftProvider.notifier).save();
      if (!mounted) return;
      if (draft.onboarding) {
        setState(() => _saving = false);
        context.push('/uang-sekarang');
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kantong disimpan')));
      context.pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Belum bisa disimpan: ${e.message}')),
      );
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showConfirmSheet(
      context,
      title: 'Buang perubahan?',
      message: 'Pengaturan kantong yang belum disimpan bakal hilang.',
      confirmLabel: 'Buang',
      danger: true,
    );
    if (leave && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(pocketDraftProvider).value;
    final dirty = draft?.dirty ?? false;

    return PopScope(
      canPop: !dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
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
                      title: draft?.onboarding ?? false
                          ? 'Bikin Sendiri'
                          : 'Atur Kantong',
                      onLeading: () => Navigator.maybePop(context),
                    ),
                    if (draft != null) ..._body(draft),
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
                  label: draft?.onboarding ?? false
                      ? 'Pakai kantong ini'
                      : 'Simpan',
                  loading: _saving,
                  onPressed: draft != null && draft.current.check.isValid
                      ? () => _save(draft)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(PocketDraft draft) {
    final setup = draft.current;
    final check = setup.check;
    final ctrl = ref.read(pocketDraftProvider.notifier);
    final nominal =
        !setup.isRunning &&
        setup.pockets.every((p) => p.mode == AllocationMode.nominal);
    return [
      const SizedBox(height: 20),
      _AllocationHero(setup: setup),
      if (!draft.onboarding && !setup.isRunning && setup.base > 0) ...[
        const SizedBox(height: 16),
        SegmentedTabs<AllocationMode>(
          items: const [
            (AllocationMode.percent, 'Persen'),
            (AllocationMode.nominal, 'Nominal'),
          ],
          value: nominal ? AllocationMode.nominal : AllocationMode.percent,
          onChanged: ctrl.setAllMode,
        ),
      ],
      const SizedBox(height: AppSpace.section),
      Row(
        children: [
          Expanded(
            child: Text(
              draft.onboarding
                  ? '${setup.pockets.length} kantong'
                  : 'Kantong kamu',
              style: AppText.style(17, AppText.w800, spacingPercent: -1),
            ),
          ),
          Text(
            draft.onboarding
                ? 'Maks $maxPockets'
                : 'Tahan & geser buat ngurutin',
            style: AppText.style(12, AppText.w700, color: AppColors.muted),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: setup.pockets.length,
        buildDefaultDragHandles: !draft.onboarding,
        onReorderItem: ctrl.reorder,
        proxyDecorator: (child, _, _) =>
            Material(color: Colors.transparent, elevation: 6, child: child),
        itemBuilder: (context, i) {
          final p = setup.pockets[i];
          return Padding(
            key: ValueKey(p.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _PocketRow(
              pocket: p,
              setup: setup,
              showNominal: nominal,
              showGrip: !draft.onboarding,
              error: !check.isValid && draft.lastEditedId == p.id,
              onTap: () => context.push('/edit-kantong/${p.id}'),
            ),
          );
        },
      ),
      if (setup.canAdd) ...[
        DashedAddCard(
          title: 'Tambah kantong',
          subtitle: 'Bisa $minPockets sampai $maxPockets kantong',
          onTap: () {
            final id = ctrl.addPocket();
            if (id != null) context.push('/edit-kantong/$id');
          },
        ),
        const SizedBox(height: 14),
      ] else
        const SizedBox(height: 4),
      if (!check.isValid)
        _WarningCard(text: _warningText(setup), onFix: ctrl.autoBalance)
      else if (!draft.onboarding)
        _InfoCard(running: setup.isRunning),
    ];
  }

  String _warningText(PocketSetup setup) {
    final check = setup.check;
    final diff = check.difference;
    final byPercent = setup.isRunning || setup.base <= 0;
    final amount = byPercent
        ? '${(check.percentSum - 100).abs()}%'
        : rupiah(diff.abs());
    return diff > 0
        ? 'Kelebihan $amount. Kurangin salah satu kantong dulu ya.'
        : 'Masih sisa $amount belum dibagi. Tambahin ke salah satu kantong ya.';
  }
}

class _AllocationHero extends StatelessWidget {
  const _AllocationHero({required this.setup});

  final PocketSetup setup;

  @override
  Widget build(BuildContext context) {
    final check = setup.check;
    final valid = check.isValid;
    final percent = check.displayPercent;
    final label = switch (setup.incomeMode) {
      _ when setup.fromOpening => 'Dari saldo awal ${rupiah(setup.base)}',
      IncomeMode.irregular => 'Dari tiap duit masuk',
      IncomeMode.allowance =>
        'Dari uang jajan ${rupiah(setup.base)} / ${setup.perNoun}',
      IncomeMode.salary => 'Dari gaji ${rupiah(setup.base)}',
    };
    final gap = (percent - 100).abs();
    final byPercent = setup.isRunning || setup.base <= 0 || check.allPercent;
    final gapText = byPercent ? '$gap%' : rupiahShort(check.difference.abs());
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.style(
                        13,
                        AppText.w500,
                        color: AppColors.faint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$percent% teralokasi',
                        style: AppText.style(
                          28,
                          AppText.w800,
                          color: valid ? Colors.white : _warn,
                          spacingPercent: -3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: valid ? AppColors.lime : _warn,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      valid ? LucideIcons.check : LucideIcons.triangleAlert,
                      size: 14,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      valid
                          ? 'Pas!'
                          : check.difference > 0
                          ? 'Lebih $gapText'
                          : 'Kurang $gapText',
                      style: AppText.style(12, AppText.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SplitBar(
            height: 10,
            parts: [
              for (final p in setup.pockets)
                (
                  setup.isRunning || setup.base <= 0
                      ? p.percent
                      : p.amountOf(setup.base) ~/ 1000,
                  p.color,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PocketRow extends StatelessWidget {
  const _PocketRow({
    required this.pocket,
    required this.setup,
    required this.showNominal,
    required this.error,
    required this.onTap,
    this.showGrip = true,
  });

  final PocketConfig pocket;
  final PocketSetup setup;
  final bool showNominal;

  /// Drag handle; tidak ada di layar 43.
  final bool showGrip;
  final bool error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(pocket.color);
    final amount = pocket.amountOf(setup.base);
    final sub = setup.isRunning
        ? '${pocketTypeLabel(pocket.type)} · tiap duit masuk'
        : '${pocketTypeLabel(pocket.type)} · ${rupiahShort(amount)}';
    final value = showNominal
        ? rupiahShort(amount)
        : '${pocket.percentOf(setup.base)}%';
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: error
            ? const BorderSide(color: AppColors.danger, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(showGrip ? 10 : 14, 14, 12, 14),
          child: Row(
            children: [
              if (showGrip) ...[
                const Icon(
                  LucideIcons.gripVertical,
                  size: 18,
                  color: AppColors.faint,
                ),
                const SizedBox(width: 6),
              ],
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.style(15, AppText.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.style(
                        12,
                        AppText.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: error
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : PocketVisuals.soft(color),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  value,
                  style: AppText.style(
                    14,
                    AppText.w800,
                    color: error ? AppColors.danger : color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6D5DFC);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PocketVisuals.soft(color),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              running
                  ? 'Nama, ikon, warna & persen bebas kamu atur. Aturan baru dipakai buat duit masuk berikutnya.'
                  : 'Nama, ikon, warna, jenis & jatah bebas kamu atur.',
              style: AppText.style(
                13,
                AppText.w700,
                color: PocketVisuals.deep(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text, required this.onFix});

  final String text;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.triangleAlert,
            size: 20,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.style(
                13,
                AppText.w700,
                color: PocketVisuals.deep(AppColors.danger),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onFix,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  'Rapiin otomatis',
                  style: AppText.style(12, AppText.w800, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
