import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// A photo saved on this phone. Fill-up photos never leave the device, so a
/// browser can only show [placeholder], even for a log synced from a phone.
Widget devicePhoto(
  String path, {
  required WidgetBuilder placeholder,
  double? width,
  double? height,
  BoxFit? fit,
  String? semanticLabel,
}) {
  if (kIsWeb) return Builder(builder: placeholder);
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    semanticLabel: semanticLabel,
    errorBuilder: (context, _, _) => placeholder(context),
  );
}
