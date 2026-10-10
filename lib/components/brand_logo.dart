import 'package:flutter/material.dart';

import '../models/brand_registry.dart';
import '../ui/app_format.dart';

/// The station brand's logo, or a tinted pump icon for unknown brands.
Widget brandLogoWidget(String brandName, double size) {
  final brand = BrandRegistry.findByName(brandName);
  if (brand != null) return brand.logo(size: size);
  return Icon(
    Icons.local_gas_station_rounded,
    size: size * 0.7,
    color: brandAccent(brandName),
  );
}
