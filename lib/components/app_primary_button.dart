import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_spinner.dart';
import '../ui/app_theme.dart';

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? trailingIcon;
  final IconData? leadingIcon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double height;
  final double borderRadius;
  final double elevation;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.trailingIcon,
    this.leadingIcon,
    this.backgroundColor = AppColors.ink,
    this.foregroundColor = Colors.white,
    this.height = 56,
    this.borderRadius = 16,
    this.elevation = 0,
  });

  Widget _content() {
    if (isLoading) {
      return Semantics(
        label: '$label, loading',
        child: AppSpinner(size: 20, color: foregroundColor),
      );
    }
    return Row(
      mainAxisAlignment: leadingIcon != null
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.center,
      children: [
        if (leadingIcon != null)
          Icon(
            leadingIcon,
            color: foregroundColor.withValues(alpha: 0.54),
            size: 20,
          ),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: foregroundColor,
            fontSize: leadingIcon != null ? 12 : 16,
            fontWeight: FontWeight.bold,
            letterSpacing: leadingIcon != null ? 2 : 0,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: 20, color: foregroundColor),
        ],
        if (leadingIcon != null && trailingIcon == null)
          Icon(
            leadingIcon,
            color: foregroundColor.withValues(alpha: 0.54),
            size: 20,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final VoidCallback? handler = isLoading ? null : onPressed;

    if (isCupertino(context)) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: CupertinoButton(
          onPressed: handler,
          color: backgroundColor,
          disabledColor: backgroundColor.withValues(alpha: 0.54),
          borderRadius: radius,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _content(),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: handler,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          elevation: elevation,
        ),
        child: _content(),
      ),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double borderRadius;

  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.borderRadius = 32,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final text = Text(
      label,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );

    if (isCupertino(context)) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: CupertinoButton(
          onPressed: onPressed,
          color: Colors.grey.shade100,
          borderRadius: radius,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: text,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade100,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        child: text,
      ),
    );
  }
}
