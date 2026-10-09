import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// True when the UI should use Cupertino (iOS-style) widgets.
///
/// Reads the theme platform so it follows `defaultTargetPlatform` in
/// production and can be overridden with `ThemeData.platform` in tests.
bool isCupertino(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Platform used for sizing decisions that happen outside the widget tree
/// (e.g. [PreferredSizeWidget.preferredSize]).
bool get isCupertinoPlatform => defaultTargetPlatform == TargetPlatform.iOS;
