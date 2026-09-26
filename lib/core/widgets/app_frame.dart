import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Bingkai semua layar. Di HP tidak berbuat apa-apa; di tablet & HP lipat
/// yang dibuka, isi dibatasi selebar HP besar ([AppSize.maxContent]) di
/// tengah, supaya kartu & tombol tidak melebar sepanjang layar.
///
/// Layar di dalamnya melihat [MediaQuery] selebar bingkai, jadi sheet,
/// dialog & snackbar ikut di tengah.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    if (width <= AppSize.maxContent) return child;

    final side = (width - AppSize.maxContent) / 2;
    // Area aman kiri/kanan (poni, engsel) sudah tertutup margin samping.
    EdgeInsets inner(EdgeInsets e) => e.copyWith(
      left: math.max(0, e.left - side),
      right: math.max(0, e.right - side),
    );
    return ColoredBox(
      color: AppColors.bg,
      child: Center(
        child: SizedBox(
          width: AppSize.maxContent,
          child: ClipRect(
            child: MediaQuery(
              data: media.copyWith(
                size: Size(AppSize.maxContent, media.size.height),
                padding: inner(media.padding),
                viewPadding: inner(media.viewPadding),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// HP biasa (sisi pendek < [AppSize.tabletShortestSide]) dikunci tegak;
/// tablet & HP lipat yang dibuka boleh diputar.
bool isCompactScreen(Size logicalSize) =>
    logicalSize.shortestSide < AppSize.tabletShortestSide;
