import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/list_card.dart';
import '../../data/providers.dart';
import '../../domain/pay_period.dart';
import '../../domain/types.dart';
import '../../domain/views.dart';

/// Layar 06 · Catatan Harian & 26 · Catatan Kosong.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(ref.read(clockProvider)());
    _month = DateTime(today.year, today.month);
    _selected = today;
  }

  Future<void> _pickMonth(DateTime today) async {
    final months = [
      for (var i = 0; i < 12; i++) DateTime(today.year, today.month - i),
    ];
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in months)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          monthYearLong(m),
                          style: AppText.style(
                            15,
                            m == _month ? AppText.w800 : AppText.w500,
                          ),
                        ),
                        trailing: m == _month
                            ? const Icon(
                                LucideIcons.check,
                                size: 18,
                                color: AppColors.ink,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, m),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _month = picked;
      final isThisMonth =
          picked.year == today.year && picked.month == today.month;
      _selected = isThisMonth ? today : DateTime(picked.year, picked.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(ref.watch(clockProvider)());
    final calendar = ref.watch(calendarMonthProvider(_month)).value;
    final notes = ref.watch(dayNotesProvider(_selected)).value;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screenX,
          8,
          AppSpace.screenX,
          24,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Catatan',
                  style: AppText.style(26, AppText.w800, spacingPercent: -3),
                ),
              ),
              _MonthPill(
                label: monthYear(_month),
                onTap: () => _pickMonth(today),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.section),
          _CalendarCard(
            month: _month,
            today: today,
            selected: _selected,
            data: calendar,
            onSelect: (d) => setState(() => _selected = d),
          ),
          const SizedBox(height: AppSpace.section),
          Row(
            children: [
              Expanded(
                child: Text(
                  dayTitle(_selected),
                  style: AppText.style(17, AppText.w800, spacingPercent: -1),
                ),
              ),
              if (notes != null)
                Text(
                  notes.total == 0 ? rupiah(0) : rupiahOut(notes.total),
                  style: AppText.style(
                    14,
                    AppText.w800,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (notes == null)
            const SizedBox(height: 120)
          else if (notes.items.isEmpty)
            _EmptyDay(
              isToday: _selected == today,
              onAdd: () => context.push('/catat?date=${_isoDate(_selected)}'),
            )
          else
            ListCard(
              children: [
                for (final e in notes.items)
                  ExpenseTile(
                    entry: e,
                    subtitle: _NoteSubtitle(entry: e),
                    onTap: () => context.push('/transaksi/${e.id}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _MonthPill extends StatelessWidget {
  const _MonthPill({required this.label, required this.onTap});

  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppText.style(13, AppText.w800)),
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: AppColors.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.today,
    required this.selected,
    required this.data,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final CalendarMonth? data;
  final ValueChanged<DateTime> onSelect;

  static const _weekdays = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  @override
  Widget build(BuildContext context) {
    // Minggu dimulai Senin.
    final leading = DateTime(month.year, month.month).weekday - 1;
    final cells = <int?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth(month.year, month.month); d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: AppText.style(
                        12,
                        AppText.w700,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (var r = 0; r < cells.length ~/ 7; r++) ...[
            if (r > 0) const SizedBox(height: 4),
            Row(
              children: [
                for (var c = 0; c < 7; c++) ...[
                  if (c > 0) const SizedBox(width: 4),
                  Expanded(child: _dayCell(cells[r * 7 + c])),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayCell(int? day) {
    if (day == null) return const SizedBox(height: 44);
    final date = DateTime(month.year, month.month, day);
    final isSelected = date == selected;
    final isFuture = date.isAfter(today);
    final isPayday = data?.paydayDay == day;
    final dots = isFuture ? const <int>[] : (data?.dots[day] ?? const <int>[]);

    final Color bg;
    final Color fg;
    if (isSelected) {
      (bg, fg) = (AppColors.ink, Colors.white);
    } else if (isPayday) {
      (bg, fg) = (AppColors.lime, AppColors.ink);
    } else {
      (bg, fg) = (
        Colors.transparent,
        isFuture ? AppColors.faint : AppColors.ink,
      );
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isFuture ? null : () => onSelect(date),
        child: SizedBox(
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: AppText.style(
                  14,
                  isSelected || isPayday ? AppText.w800 : AppText.w700,
                  color: fg,
                ),
              ),
              if (isPayday && !isSelected) ...[
                const SizedBox(height: 1),
                Text('gajian', style: AppText.style(8, AppText.w800)),
              ] else if (dots.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, c) in dots.take(3).indexed) ...[
                      if (i > 0) const SizedBox(width: 3),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteSubtitle extends StatelessWidget {
  const _NoteSubtitle({required this.entry});

  final ExpenseEntry entry;

  @override
  Widget build(BuildContext context) {
    final extra = [
      clock(entry.occurredAt),
      if (entry.source == ExpenseSource.scan) 'dari scan',
    ].join(' · ');
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: entry.pocket.name,
            style: AppText.style(
              12,
              AppText.w700,
              color: Color(entry.pocket.color),
            ),
          ),
          TextSpan(
            text: ' · $extra',
            style: AppText.style(12, AppText.w500, color: AppColors.muted),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.isToday, required this.onAdd});

  final bool isToday;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const IconBadge(
            icon: LucideIcons.wallet,
            background: AppColors.lime,
            color: AppColors.ink,
            size: 56,
            iconSize: 26,
            square: true,
          ),
          const SizedBox(height: 10),
          Text(
            isToday
                ? 'Nggak ada jajan hari ini!'
                : 'Nggak ada jajan di hari ini!',
            style: AppText.style(16, AppText.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Hemat parah. Kalau ada yang kelupaan,\ncatat aja di sini.',
            textAlign: TextAlign.center,
            style: AppText.style(13, AppText.w500, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Material(
            color: AppColors.ink,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAdd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.plus,
                      size: 16,
                      color: AppColors.lime,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tambah catatan',
                      style: AppText.style(
                        13,
                        AppText.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
