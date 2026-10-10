import 'package:flutter/material.dart';

import '../ui/adaptive/app_icon_button.dart';
import '../ui/app_theme.dart';

/// Round icon-only button. [tooltip] is required because it is the only
/// name screen readers can announce for an icon with no visible text.
class AppCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const AppCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 48,
    this.iconSize = 20,
    this.backgroundColor = Colors.white,
    this.iconColor = AppColors.text,
    this.boxShadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: border ?? Border.all(color: AppColors.divider),
        boxShadow:
            boxShadow ??
            const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
      ),
      child: AppIconButton(
        icon: Icon(icon, color: iconColor, size: iconSize),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
