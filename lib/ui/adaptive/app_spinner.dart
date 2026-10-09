import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_platform.dart';

/// Loading indicator: [CupertinoActivityIndicator] on iOS,
/// [CircularProgressIndicator] elsewhere.
///
/// When [size] is null the platform default size is used.
class AppSpinner extends StatelessWidget {
  final double? size;
  final Color? color;
  final double? strokeWidth;

  const AppSpinner({super.key, this.size, this.color, this.strokeWidth});

  @override
  Widget build(BuildContext context) {
    final Widget indicator = isCupertino(context)
        ? CupertinoActivityIndicator(radius: (size ?? 20) / 2, color: color)
        : CircularProgressIndicator(
            strokeWidth: strokeWidth ?? 4,
            color: color,
          );

    if (size == null) return indicator;
    return SizedBox(width: size, height: size, child: indicator);
  }
}
