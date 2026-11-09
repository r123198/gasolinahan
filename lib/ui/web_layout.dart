import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app_theme.dart';

const webPageMaxWidth = 560.0;
const webTabMaxWidth = 720.0;
const webNavMaxWidth = 480.0;
const webMapControlsMaxWidth = 420.0;

/// Stops phone-shaped layouts stretching across a desktop browser. Does
/// nothing in the phone apps.
class WebWidthLimit extends StatelessWidget {
  final double maxWidth;
  final Alignment alignment;
  final double? heightFactor;
  final Widget child;

  const WebWidthLimit({
    super.key,
    required this.maxWidth,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.heightFactor,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return Align(
      alignment: alignment,
      heightFactor: heightFactor,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A whole screen (sign in, report form) as a centred column on the web.
class WebPageFrame extends StatelessWidget {
  final Widget child;

  const WebPageFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return ColoredBox(
      color: AppColors.background,
      child: WebWidthLimit(maxWidth: webPageMaxWidth, child: child),
    );
  }
}
