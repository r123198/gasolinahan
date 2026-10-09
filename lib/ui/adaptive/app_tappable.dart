import 'package:flutter/material.dart';

import 'app_platform.dart';

const _pressedOpacity = 0.6;
const _pressFade = Duration(milliseconds: 120);

/// Tap target for custom-styled rows and tiles: ink ripple on Android,
/// iOS-style press-fade on iOS.
class AppTappable extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Widget child;

  const AppTappable({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.borderRadius,
  });

  @override
  State<AppTappable> createState() => _AppTappableState();
}

class _AppTappableState extends State<AppTappable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!isCupertino(context)) {
      return InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: widget.borderRadius,
        child: widget.child,
      );
    }

    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: AnimatedOpacity(
          duration: _pressFade,
          opacity: _pressed ? _pressedOpacity : 1,
          child: widget.child,
        ),
      ),
    );
  }
}
