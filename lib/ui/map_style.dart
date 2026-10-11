import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Soft greyscale for the OpenStreetMap tiles (an Airbnb-style quiet map):
/// luminance only, lifted toward white so roads and labels stay readable
/// while the coloured price markers carry the attention.
///
/// out = luminance × [_contrast] + [_lift], per channel, 0–255.
const _contrast = 0.82;
const _lift = 40.0;
const _r = 0.2126 * _contrast;
const _g = 0.7152 * _contrast;
const _b = 0.0722 * _contrast;

const monochromeMapFilter = ColorFilter.matrix(<double>[
  _r, _g, _b, 0, _lift, //
  _r, _g, _b, 0, _lift, //
  _r, _g, _b, 0, _lift, //
  0, 0, 0, 1, 0, //
]);

/// [TileLayer.tileBuilder] that renders each tile in [monochromeMapFilter].
Widget monochromeTileBuilder(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) => ColorFiltered(colorFilter: monochromeMapFilter, child: tileWidget);
