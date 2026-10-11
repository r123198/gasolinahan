import 'package:flutter/material.dart';

import '../models/brand_registry.dart';
import '../ui/app_format.dart';

/// The brand's emblem (logo without its name), or a tinted pump icon for
/// unknown brands. [stationName] lets a typed name like "Petron Mayapa"
/// still find its brand when none was stored.
Widget brandLogoWidget(
  String brandName,
  double size, {
  String stationName = '',
}) {
  final brand = BrandRegistry.match(brandName, stationName: stationName);
  if (brand != null) return brand.mark(size: size);
  return Icon(
    Icons.local_gas_station_rounded,
    size: size * 0.7,
    color: brandAccent(brandName),
  );
}
