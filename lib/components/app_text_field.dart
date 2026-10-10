import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/app_theme.dart';

/// Text input with an optional persistent label above it and an error line
/// below it. Material fields take their borders from the app theme's
/// [InputDecorationTheme]; the iOS field draws the same borders itself.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
    this.enabled = true,
  });

  bool get _obscured => isPassword && obscureText;

  @override
  Widget build(BuildContext context) {
    final field = isCupertino(context)
        ? _CupertinoField(field: this)
        : _materialField();
    if (label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label!,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget? _passwordToggle() {
    if (!isPassword) return null;
    return AppIconButton(
      icon: Icon(
        obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.textMuted,
        size: 20,
      ),
      tooltip: obscureText ? 'Show password' : 'Hide password',
      onPressed: onToggleObscure,
    );
  }

  Widget _materialField() {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: _obscured,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: enabled ? autofillHints : null,
      textCapitalization: textCapitalization,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 16, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        errorMaxLines: 2,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: _passwordToggle(),
      ),
    );
  }
}

class _CupertinoField extends StatelessWidget {
  final AppTextField field;

  const _CupertinoField({required this.field});

  @override
  Widget build(BuildContext context) {
    final error = field.errorText;
    final borderColor = error != null ? AppColors.error : AppColors.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoTextField(
          controller: field.controller,
          focusNode: field.focusNode,
          enabled: field.enabled,
          obscureText: field._obscured,
          keyboardType: field.keyboardType,
          textInputAction: field.textInputAction,
          autofillHints: field.enabled ? field.autofillHints : null,
          textCapitalization: field.textCapitalization,
          onSubmitted: field.onSubmitted,
          onChanged: field.onChanged,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            color: AppColors.text,
          ),
          placeholder: field.hint,
          placeholderStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            color: AppColors.textMuted,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(field.icon, color: AppColors.textMuted, size: 20),
          ),
          suffix: field._passwordToggle(),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
