import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/app_theme.dart';

/// Above this sheet extent the stations list is the focus, so the button
/// gets out of the way.
const _hideAboveExtent = 0.6;
const _gapAboveSheet = 12.0;
const _fadeDuration = Duration(milliseconds: 180);

/// "Report price" button floating on the map, riding just above the
/// draggable stations sheet. Must be a direct child of the map tab's
/// [Stack], which the sheet's extent fractions are measured against.
class ReportPriceFab extends StatelessWidget {
  final ValueListenable<double> sheetExtent;
  final VoidCallback onPressed;

  const ReportPriceFab({
    super.key,
    required this.sheetExtent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _fadeDuration;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) => ValueListenableBuilder<double>(
          valueListenable: sheetExtent,
          builder: (context, extent, child) {
            final isHidden = extent > _hideAboveExtent;
            return Stack(
              children: [
                Positioned(
                  right: 16,
                  bottom: extent * constraints.maxHeight + _gapAboveSheet,
                  child: IgnorePointer(
                    ignoring: isHidden,
                    child: ExcludeSemantics(
                      excluding: isHidden,
                      child: AnimatedOpacity(
                        opacity: isHidden ? 0 : 1,
                        duration: fade,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: FloatingActionButton.extended(
            heroTag: 'report-price',
            onPressed: onPressed,
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Report price'),
          ),
        ),
      ),
    );
  }
}
