import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_platform.dart';

/// Borderless text button: [CupertinoButton] on iOS, [TextButton] elsewhere.
///
/// [foregroundColor] tints the label on both platforms.
class AppTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final Alignment? alignment;

  const AppTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.foregroundColor,
    this.padding,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCupertino(context)) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          padding: padding,
          alignment: alignment,
        ),
        child: child,
      );
    }

    final button = CupertinoButton(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, kMinInteractiveDimensionCupertino),
      alignment: alignment ?? Alignment.center,
      onPressed: onPressed,
      child: child,
    );
    if (foregroundColor == null) return button;
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(primaryColor: foregroundColor),
      child: button,
    );
  }
}
