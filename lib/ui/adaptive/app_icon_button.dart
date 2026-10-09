import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_platform.dart';

/// Icon button: [CupertinoButton] (press-fade, no ripple) on iOS,
/// [IconButton] elsewhere.
class AppIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCupertino(context)) {
      return IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        padding: padding ?? const EdgeInsets.all(8),
      );
    }

    final button = CupertinoButton(
      padding: padding ?? const EdgeInsets.all(8),
      minimumSize: const Size.square(kMinInteractiveDimensionCupertino),
      onPressed: onPressed,
      child: icon,
    );
    return tooltip == null ? button : Semantics(label: tooltip, child: button);
  }
}
