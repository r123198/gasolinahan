import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'app_platform.dart';

/// Yes/no confirmation using the platform's alert style. Resolves to true
/// only when the user taps [confirmLabel]; dismissing counts as cancel.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message),
      actions: [
        _action(dialogContext, cancelLabel, false),
        _action(
          dialogContext,
          confirmLabel,
          true,
          isDestructive: isDestructive,
          isDefault: true,
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Widget _action(
  BuildContext context,
  String label,
  bool result, {
  bool isDestructive = false,
  bool isDefault = false,
}) {
  final color = isDestructive ? AppColors.error : AppColors.ink;
  return adaptiveDialogAction(
    context: context,
    label: label,
    color: color,
    isDestructive: isDestructive,
    isDefault: isDefault,
    onPressed: () => Navigator.pop(context, result),
  );
}

/// A [TextButton] on Android; a [CupertinoDialogAction] on iOS.
Widget adaptiveDialogAction({
  required BuildContext context,
  required String label,
  required VoidCallback onPressed,
  Color color = AppColors.ink,
  bool isDestructive = false,
  bool isDefault = false,
}) {
  if (isCupertino(context)) {
    return CupertinoDialogAction(
      isDestructiveAction: isDestructive,
      isDefaultAction: isDefault,
      onPressed: onPressed,
      child: Text(label),
    );
  }
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: color),
    child: Text(
      label,
      style: TextStyle(fontWeight: isDefault ? FontWeight.w700 : null),
    ),
  );
}
