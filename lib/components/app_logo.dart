import 'package:flutter/material.dart';

import '../ui/app_theme.dart';

const _markAsset = 'assets/images/brand/gasolinahan_mark.png';

/// The Gasolinahan mark, optionally with the spaced-out wordmark under it
/// (as on the splash and sign-in screens).
class AppLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const AppLogo({super.key, this.size = 48, this.showWordmark = false});

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      _markAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: showWordmark ? null : 'Gasolinahan',
    );
    if (!showWordmark) return mark;
    return Semantics(
      label: 'Gasolinahan',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(height: size * 0.22),
          Text(
            'GASOLINAHAN',
            style: TextStyle(
              fontSize: (size * 0.16).clamp(14, 24),
              fontWeight: FontWeight.w500,
              letterSpacing: 4,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
