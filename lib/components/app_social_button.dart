import 'package:flutter/material.dart';

import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/app_theme.dart';

class AppSocialButton extends StatelessWidget {
  final String? label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isCircle;

  const AppSocialButton({
    super.key,
    this.label,
    required this.icon,
    this.onPressed,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCircle) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: AppIconButton(
          icon: Icon(icon, color: Colors.black),
          onPressed: onPressed ?? () {},
        ),
      );
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: AppTappable(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed ?? () {},
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.black),
              if (label != null) ...[
                const SizedBox(width: 8),
                Text(
                  label!,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
