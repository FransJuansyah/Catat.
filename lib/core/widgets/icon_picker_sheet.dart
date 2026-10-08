import 'package:flutter/material.dart';

import '../../domain/templates.dart';
import '../theme/tokens.dart';
import 'app_button.dart';
import 'icon_badge.dart';

/// Lembar "Pilih ikon" (layar 68): ikon dikelompokkan (Uang & tagihan, Jalan,
/// Harian, Lainnya). Dipakai untuk kantong & tagihan. null = ditutup.
Future<String?> showIconPicker(
  BuildContext context, {
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (_) => _IconPicker(selected: selected),
  );
}

class _IconPicker extends StatefulWidget {
  const _IconPicker({required this.selected});

  final String selected;

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  late String _key = widget.selected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                'Pilih ikon',
                style: AppText.style(20, AppText.w800, spacingPercent: -2),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (group, keys) in pocketIconGroups) ...[
                      const SizedBox(height: 14),
                      Text(
                        group,
                        style: AppText.style(
                          13,
                          AppText.w700,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.95,
                        children: [for (final k in keys) _cell(k)],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Pakai ikon ini',
                onPressed: () => Navigator.pop(context, _key),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(String key) {
    final on = key == _key;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _key = key),
      child: Column(
        children: [
          IconBadge(
            icon: PocketVisuals.icon(key),
            background: on ? AppColors.ink : AppColors.track,
            color: on ? AppColors.lime : AppColors.ink,
            size: 52,
            iconSize: 24,
            square: true,
          ),
          const SizedBox(height: 6),
          Text(
            pocketIconLabels[key] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.style(
              11,
              on ? AppText.w800 : AppText.w500,
              color: on ? AppColors.ink : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
