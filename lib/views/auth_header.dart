import 'package:flutter/material.dart';

import '../ui/adaptive/app_text_button.dart';
import '../ui/app_theme.dart';

/// Logo mark, title and one-line pitch shared by sign-in and sign-up.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_gas_station_rounded,
              color: AppColors.go,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(header: true, child: Text(title, style: text.headlineMedium)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: text.bodyLarge?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// "Don't have an account? Create one" row under the auth forms.
class AuthSwitchPrompt extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onPressed;

  const AuthSwitchPrompt({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
        AppTextButton(
          onPressed: onPressed,
          foregroundColor: AppColors.ink,
          child: Text(
            action,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
