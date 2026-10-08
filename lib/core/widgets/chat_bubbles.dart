import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import 'icon_badge.dart';

/// Gelembung pesan user (kanan, hitam).
class ChatUserBubble extends StatelessWidget {
  const ChatUserBubble({super.key, required this.text, this.onTap});

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

/// Gelembung bot (layar 65–66): avatar lime di kiri, latar putih; kuning untuk
/// peringatan (offline, ditolak, jatah habis).
class ChatBotBubble extends StatelessWidget {
  const ChatBotBubble({
    super.key,
    required this.text,
    this.warn = false,
    this.icon,
    this.action,
    this.onAction,
  }) : typing = false;

  /// Titik-titik "lagi ngetik" saat menunggu AI.
  const ChatBotBubble.typing({super.key})
    : text = '',
      warn = false,
      icon = null,
      action = null,
      onAction = null,
      typing = true;

  final String text;

  /// Peringatan (offline, ditolak, jatah habis): latar kuning.
  final bool warn;
  final IconData? icon;

  /// Tombol kecil di dalam gelembung, mis. "Pakai Manual".
  final String? action;
  final VoidCallback? onAction;

  final bool typing;

  @override
  Widget build(BuildContext context) {
    final fg = warn ? AppColors.warnText : AppColors.ink;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon:
                icon ??
                (warn ? LucideIcons.triangleAlert : LucideIcons.sparkles),
            background: warn ? AppColors.warnBadge : AppColors.lime,
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
                    const ChatTypingDots()
                  else
                    Text(
                      text,
                      style: AppText.style(15, AppText.w500, color: fg),
                    ),
                  if (action != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: onAction,
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
                          action!,
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
class ChatTypingDots extends StatefulWidget {
  const ChatTypingDots({super.key});

  @override
  State<ChatTypingDots> createState() => ChatTypingDotsState();
}

class ChatTypingDotsState extends State<ChatTypingDots>
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

/// Kotak ketik chat + tombol kirim (layar 60, 65, 74).
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
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
