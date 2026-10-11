import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_platform.dart';

const _sheetRadius = Radius.circular(24);
const _sheetMaxHeightFactor = 0.9;

/// Modal bottom sheet. Android uses [showModalBottomSheet]; iOS presents the
/// same content with [showCupertinoModalPopup] on a rounded surface that
/// follows the keyboard. [enableDrag] only applies on Android.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  bool enableDrag = true,
}) {
  if (!isCupertino(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      // Swipe-to-dismiss ignores PopScope, so forms with unsaved input
      // turn it off and rely on Back/barrier taps, which do respect it.
      enableDrag: enableDrag,
      builder: builder,
    );
  }

  final isTransparent = backgroundColor == Colors.transparent;
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (popupContext) {
      final media = MediaQuery.of(popupContext);
      // A bottom sheet never reaches the status bar, so drop the top inset
      // (as Material's sheet does); otherwise any SafeArea inside the sheet
      // adds a status-bar-tall gap above the content.
      final content = MediaQuery.removePadding(
        context: popupContext,
        removeTop: true,
        child: Builder(builder: builder),
      );
      return AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height * _sheetMaxHeightFactor,
          ),
          child: Material(
            color:
                backgroundColor ?? Theme.of(popupContext).colorScheme.surface,
            clipBehavior: isTransparent ? Clip.none : Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: _sheetRadius),
            child: isTransparent
                ? Padding(
                    padding: EdgeInsets.only(
                      bottom: media.viewInsets.bottom > 0
                          ? 0
                          : media.viewPadding.bottom,
                    ),
                    child: content,
                  )
                : content,
          ),
        ),
      );
    },
  );
}

/// One choice in [showAppActionSheet].
class AppSheetAction<T> {
  final String label;
  final T value;
  final IconData? icon;
  final bool isDestructive;

  const AppSheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDestructive = false,
  });
}

/// Short list of choices: [CupertinoActionSheet] on iOS, a bottom sheet of
/// list tiles on Android. Returns the chosen value, or null if dismissed.
Future<T?> showAppActionSheet<T>({
  required BuildContext context,
  required List<AppSheetAction<T>> actions,
  String? title,
  String cancelLabel = 'Cancel',
}) {
  if (isCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: action.isDestructive,
              onPressed: () => Navigator.pop(popupContext, action.value),
              child: Text(action.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
          for (final action in actions)
            ListTile(
              leading: action.icon == null ? null : Icon(action.icon),
              title: Text(
                action.label,
                style: action.isDestructive
                    ? TextStyle(color: Theme.of(sheetContext).colorScheme.error)
                    : null,
              ),
              onTap: () => Navigator.pop(sheetContext, action.value),
            ),
        ],
      ),
    ),
  );
}
