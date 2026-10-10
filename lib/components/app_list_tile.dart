import 'package:flutter/material.dart';

import '../ui/adaptive/app_tappable.dart';
import '../ui/app_theme.dart';

class AppListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool isDestructive;
  final VoidCallback? onTap;
  final Color? iconBackgroundColor;
  final BoxShape iconShape;

  const AppListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.isDestructive = false,
    this.onTap,
    this.iconBackgroundColor,
    this.iconShape = BoxShape.circle,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        iconBackgroundColor ??
        (isDestructive ? const Color(0xFFFEF2F2) : AppColors.surfaceMuted);
    final contentColor = isDestructive ? AppColors.error : AppColors.text;

    return AppTappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bgColor, shape: iconShape),
              child: Icon(icon, color: contentColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: contentColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (!isDestructive)
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class AppDetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const AppDetailRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
