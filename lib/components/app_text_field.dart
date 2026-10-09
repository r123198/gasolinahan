import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/app_theme.dart';

const _hintColor = Color(0xFF94A3B8);

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return _buildLabeledField(context);
    }
    return _buildSimpleField(context);
  }

  Widget _labeledInput(BuildContext context) {
    const style = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    );
    const hintStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      color: _hintColor,
      fontWeight: FontWeight.w600,
      fontSize: 16,
    );

    if (isCupertino(context)) {
      return CupertinoTextField(
        controller: controller,
        obscureText: isPassword && obscureText,
        style: style,
        placeholder: hint,
        placeholderStyle: hintStyle,
        decoration: null,
        padding: EdgeInsets.zero,
      );
    }
    return TextField(
      controller: controller,
      obscureText: isPassword && obscureText,
      style: style,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: hintStyle,
        border: InputBorder.none,
        isDense: true,
      ),
    );
  }

  Widget _buildLabeledField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 2),
            color: Colors.white,
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(icon, color: Colors.black, size: 20),
              const SizedBox(width: 12),
              Expanded(child: _labeledInput(context)),
              if (isPassword)
                AppIconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: _hintColor,
                  ),
                  onPressed: onToggleObscure,
                )
              else
                const SizedBox(width: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleField(BuildContext context) {
    const hintStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      color: _hintColor,
      fontSize: 14,
    );

    final Widget input = isCupertino(context)
        ? CupertinoTextField(
            controller: controller,
            obscureText: isPassword && obscureText,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              color: Colors.black,
            ),
            placeholder: hint,
            placeholderStyle: hintStyle,
            decoration: null,
            padding: const EdgeInsets.symmetric(vertical: 16),
            prefix: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(icon, color: _hintColor, size: 20),
            ),
          )
        : TextField(
            controller: controller,
            obscureText: isPassword && obscureText,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: hintStyle,
              prefixIcon: Icon(icon, color: _hintColor, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: input,
    );
  }
}
