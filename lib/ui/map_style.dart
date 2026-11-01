import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// The basemap: OpenFreeMap's Positron style, rendered on the phone from
/// vector tiles. Free, no API key, no usage cap, drawn from OpenStreetMap
/// data. Positron keeps roads, street names, parks, water and building
/// outlines but leaves out the shop and diner pins that bury the price
/// markers on the standard OpenStreetMap tiles.
const basemapStyleUrl = 'https://tiles.openfreemap.org/styles/positron';

/// Credit the basemap requires beside the map.
const basemapCredit = '© OpenStreetMap contributors · OpenFreeMap';

/// Loads the style (theme, tile sources, sprites). One short request on
/// first open; tiles are then cached on disk by the layer.
Future<Style> readBasemapStyle() => StyleReader(uri: basemapStyleUrl).read();

/// The map's tile layer for the current state of [style]: the vector
/// basemap once its style has loaded, plain OpenStreetMap tiles (toned
/// down to greyscale) if the style can't be fetched, nothing while it
/// loads so the map doesn't flash from one look to another.
Widget basemapLayer(BuildContext context, AsyncSnapshot<Style> style) {
  final loaded = style.data;
  if (loaded != null) {
    return VectorTileLayer(
      tileProviders: loaded.providers,
      theme: loaded.theme,
      sprites: loaded.sprites,
      maximumZoom: 18,
      // Rasterised on the phone: smoothest panning; still re-rendered
      // from vectors at each zoom level so labels stay sharp.
      layerMode: VectorTileLayerMode.raster,
    );
  }
  if (style.hasError) {
    debugPrint('Basemap style unavailable, using OSM tiles: ${style.error}');
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.maalam.gasolinahan',
      tileBuilder: monochromeTileBuilder,
    );
  }
  return const SizedBox.shrink();
}

/// Soft greyscale for the fallback OpenStreetMap tiles: luminance only,
/// lifted toward white so roads and labels stay readable while the
/// coloured price markers carry the attention.
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
