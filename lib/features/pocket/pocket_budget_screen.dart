import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/amount_keypad.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/icon_badge.dart';
import '../../data/providers.dart';
import '../../domain/pocket_config.dart';
import '../../domain/types.dart';
import 'pocket_widgets.dart';

const _presets = [10, 20, 30, 40];

/// Layar 22 · Atur Jatah & Rentang satu kantong. Masuk ke draft layar 20.
class PocketBudgetScreen extends ConsumerStatefulWidget {
  const PocketBudgetScreen({super.key, required this.pocketId});

  final String pocketId;

  @override
  ConsumerState<PocketBudgetScreen> createState() => _PocketBudgetScreenState();
}

class _PocketBudgetScreenState extends ConsumerState<PocketBudgetScreen> {
  PocketConfig? _p;

  void _set(PocketConfig next) => setState(() => _p = next);

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(pocketDraftProvider).value;
    final fromDraft = draft?.current.pockets
        .where((p) => p.id == widget.pocketId)
        .firstOrNull;
    _p ??= fromDraft;
    final p = _p;

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
                  AppTopBar(title: p?.name ?? ''),
                  if (p != null && draft != null) ..._body(p, draft.current),
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
                label: 'Simpan jatah',
                onPressed: p == null
                    ? null
                    : () {
                        ref.read(pocketDraftProvider.notifier).updatePocket(p);
                        context.pop();
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(PocketConfig p, PocketSetup setup) {
    final color = Color(p.color);
    final base = setup.base;
    final running = setup.isRunning;
    final source = setup.incomeMode == IncomeMode.allowance
        ? 'uang jajan'
        : 'gaji';
    final pct = p.percentOf(base);
    final emergency = setup.pockets
        .where((o) => o.type == PocketType.darurat && o.id != p.id)
        .firstOrNull;

    final String headline;
    final String caption;
    if (running) {
      headline = '$pct%';
      caption = base > 0
          ? '≈ ${rupiah(p.amountOf(base))} dari perkiraan ${rupiah(base)} / bulan'
          : 'dari tiap duit masuk';
    } else {
      headline = rupiah(p.amountOf(base));
      caption = p.mode == AllocationMode.percent
          ? '$pct% dari $source ${rupiah(base)}'
          : 'Nominal tetap · $pct% dari $source ${rupiah(base)}';
    }

    return [
      const SizedBox(height: 20),
      Center(
        child: Text(
          running ? 'Jatah tiap duit masuk' : 'Jatah per ${setup.perNoun}',
          style: AppText.style(13, AppText.w500, color: AppColors.muted),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            headline,
            style: AppText.style(40, AppText.w800, spacingPercent: -3),
          ),
        ),
      ),
      Center(
        child: Text(
          caption,
          textAlign: TextAlign.center,
          style: AppText.style(13, AppText.w500, color: AppColors.muted),
        ),
      ),
      const SizedBox(height: AppSpace.section),
      _usageCard(p, base, color, allowNominal: !running && base > 0),
      if (!running) ...[
        const SizedBox(height: 14),
        _rangeCard(p, base, color, source),
      ],
      const SizedBox(height: 14),
      WhiteCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            _toggleRow(
              icon: LucideIcons.bell,
              text:
                  'Ingetin kalau sisa di bawah ${p.lowThresholdPercent == 0 ? 20 : p.lowThresholdPercent}%',
              value: p.lowThresholdPercent > 0,
              onChanged: (v) =>
                  _set(p.copyWith(lowThresholdPercent: v ? 20 : 0)),
            ),
            if (!running && emergency != null) ...[
              const Divider(height: 1, color: AppColors.line),
              _toggleRow(
                icon: LucideIcons.repeat,
                text: 'Sisa akhir ${setup.perNoun} pindah ke ${emergency.name}',
                value: p.rolloverToEmergency,
                onChanged: (v) => _set(p.copyWith(rolloverToEmergency: v)),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _usageCard(
    PocketConfig p,
    int base,
    Color color, {
    required bool allowNominal,
  }) {
    final nominal = p.mode == AllocationMode.nominal;
    final top = nominal ? math.max(base, p.nominal) : 100;
    final value = nominal ? p.nominal : p.percent;
    final presetValues = [
      for (final x in _presets) nominal ? base * x ~/ 100 : x,
    ];
    final custom = !presetValues.contains(value);

    Future<void> pickCustom() async {
      final picked = nominal
          ? await showAmountSheet(
              context,
              title: 'Jatah ${p.name}',
              initial: p.nominal,
              confirmLabel: 'Pakai',
            )
          : await showPercentSheet(context, initial: p.percent);
      if (picked == null) return;
      _set(nominal ? p.copyWith(nominal: picked) : p.copyWith(percent: picked));
    }

    String tick(int i) => nominal ? rupiahShort(top * i ~/ 4) : '${25 * i}%';

    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Atur pakai',
                  style: AppText.style(15, AppText.w800),
                ),
              ),
              if (allowNominal)
                SizedBox(
                  width: 170,
                  child: SegmentedTabs<AllocationMode>(
                    items: const [
                      (AllocationMode.percent, 'Persen'),
                      (AllocationMode.nominal, 'Nominal'),
                    ],
                    value: p.mode,
                    onChanged: (m) => _set(p.withMode(m, base)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: pocketSliderTheme(context, color),
            child: Slider(
              value: value.clamp(0, top).toDouble(),
              max: top.toDouble(),
              divisions: 100,
              onChanged: (v) {
                if (nominal) {
                  // Kelipatan Rp 10.000 biar rapi.
                  _set(p.copyWith(nominal: (v / 10000).round() * 10000));
                } else {
                  _set(p.copyWith(percent: v.round()));
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i <= 4; i++)
                  Text(
                    tick(i),
                    style: AppText.style(
                      11,
                      AppText.w500,
                      color: AppColors.faint,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (i, x) in _presets.indexed) ...[
                Expanded(
                  child: PillChip(
                    label: nominal
                        ? rupiahShort(presetValues[i]).replaceFirst('Rp ', '')
                        : '$x%',
                    selected: value == presetValues[i],
                    color: color,
                    onTap: () => _set(
                      nominal
                          ? p.copyWith(nominal: presetValues[i])
                          : p.copyWith(percent: x),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                flex: 2,
                child: PillChip(
                  label: custom && value > 0
                      ? (nominal
                            ? rupiahShort(value).replaceFirst('Rp ', '')
                            : '$value%')
                      : 'Custom',
                  selected: custom,
                  color: color,
                  onTap: pickCustom,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rangeCard(PocketConfig p, int base, Color color, String source) {
    final amount = p.amountOf(base);
    final top = [
      base,
      amount,
      p.rangeMax ?? 0,
      p.rangeMin ?? 0,
    ].reduce(math.max).clamp(100000, 1 << 40);
    final lo = (p.rangeMin ?? 0).clamp(0, top).toDouble();
    final hi = (p.rangeMax ?? top).clamp(0, top).toDouble();

    var clamped = amount;
    if (p.rangeMin != null) clamped = math.max(clamped, p.rangeMin!);
    if (p.rangeMax != null) clamped = math.min(clamped, p.rangeMax!);

    int step(double v) => (v / 10000).round() * 10000;

    Future<void> edit({required bool min}) async {
      final picked = await showAmountSheet(
        context,
        title: min ? 'Jatah minimal' : 'Jatah maksimal',
        initial: (min ? p.rangeMin : p.rangeMax) ?? 0,
        confirmLabel: 'Pakai',
      );
      if (picked == null) return;
      if (min) {
        final max = p.rangeMax;
        _set(
          p.copyWith(
            rangeMin: () => picked,
            rangeMax: () => max != null && max < picked ? picked : max,
          ),
        );
      } else {
        final minV = p.rangeMin;
        _set(
          p.copyWith(
            rangeMax: () => picked,
            rangeMin: () => minV != null && minV > picked ? picked : minV,
          ),
        );
      }
    }

    Widget box(String label, int? value, {required bool min}) => Expanded(
      child: Material(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => edit(min: min),
          onLongPress: () => _set(
            min
                ? p.copyWith(rangeMin: () => null)
                : p.copyWith(rangeMax: () => null),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value == null ? 'Tanpa batas' : rupiah(value),
                    style: AppText.style(
                      16,
                      AppText.w800,
                      color: value == null ? AppColors.faint : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rentang jatah',
                  style: AppText.style(15, AppText.w800),
                ),
              ),
              Text(
                'kalau $source naik/turun',
                style: AppText.style(12, AppText.w700, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: pocketSliderTheme(context, color),
            child: RangeSlider(
              values: RangeValues(lo, hi),
              max: top.toDouble(),
              divisions: 100,
              onChanged: (v) {
                final min = step(v.start);
                final max = step(v.end);
                _set(
                  p.copyWith(
                    rangeMin: () => min <= 0 ? null : min,
                    rangeMax: () => max >= top ? null : max,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              box('Minimal', p.rangeMin, min: true),
              const SizedBox(width: 10),
              box('Maksimal', p.rangeMax, min: false),
            ],
          ),
          if (clamped != amount) ...[
            const SizedBox(height: 10),
            Text(
              'Jatah ${p.name} jadi ${rupiah(clamped)} karena rentang ini.',
              style: AppText.style(12, AppText.w700, color: color),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          IconBadge(
            icon: icon,
            background: AppColors.bg,
            color: AppColors.ink,
            size: 40,
            square: true,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.style(14, AppText.w700))),
          const SizedBox(width: 8),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
