import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/month_picker.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/list_card.dart';
import '../../data/providers.dart';
import '../../domain/pay_period.dart';
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
    final picked = await showMonthSheet(
      context,
      months: months,
      selected: _month,
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
              MonthPill(
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
              if (notes != null && notes.incomeTotal > 0) ...[
                Text(
                  '+${rupiahShort(notes.incomeTotal).substring(3)}',
                  style: AppText.style(
                    14,
                    AppText.w800,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (notes != null && (notes.incomeTotal == 0 || notes.total > 0))
                Text(
                  notes.incomeTotal > 0
                      ? '-${rupiahShort(notes.total).substring(3)}'
                      : (notes.total == 0 ? rupiah(0) : rupiahOut(notes.total)),
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
          else if (notes.isEmpty)
            _EmptyDay(
              isToday: _selected == today,
              onAdd: () => context.push('/catat?date=${_isoDate(_selected)}'),
            )
          else
            ListCard(
              children: [
                for (final i in notes.incomes)
                  _IncomeTile(
                    entry: i,
                    onTap: i.auto
                        ? null
                        : () => context.push('/pemasukan?edit=${i.id}'),
                  ),
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
          if (data?.incomeDays.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            const _Legend(),
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
    final isIncome = !isFuture && (data?.incomeDays.contains(day) ?? false);
    final dots = isFuture ? const <int>[] : (data?.dots[day] ?? const <int>[]);

    final Color bg;
    final Color fg;
    if (isSelected) {
      (bg, fg) = (AppColors.ink, Colors.white);
    } else if (isPayday) {
      (bg, fg) = (AppColors.lime, AppColors.ink);
    } else if (isIncome) {
      (bg, fg) = (_incomeSoft, _incomeText);
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
    final extra = [clock(entry.occurredAt), ?entry.source.tag].join(' · ');
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

const _incomeSoft = Color(0xFFE2F6EC);
const _incomeText = Color(0xFF0B6B45);

/// Baris pemasukan di Catatan (layar 34). Pemasukan otomatis tidak bisa dihapus.
class _IncomeTile extends StatelessWidget {
  const _IncomeTile({required this.entry, this.onTap});

  final IncomeEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            const IconBadge(
              icon: LucideIcons.circlePlus,
              background: _incomeSoft,
              color: AppColors.success,
              size: 40,
              iconSize: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.style(15, AppText.w800),
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Pemasukan',
                          style: AppText.style(
                            12,
                            AppText.w700,
                            color: AppColors.success,
                          ),
                        ),
                        TextSpan(
                          text: entry.auto
                              ? ' \u00b7 otomatis'
                              : ' \u00b7 ${clock(entry.occurredAt)}',
                          style: AppText.style(
                            12,
                            AppText.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${rupiah(entry.amount)}',
              style: AppText.style(15, AppText.w800, color: AppColors.success),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _incomeSoft,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Ada pemasukan',
            style: AppText.style(11, AppText.w700, color: AppColors.muted),
          ),
          const SizedBox(width: 14),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Pengeluaran per kantong',
            style: AppText.style(11, AppText.w700, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
