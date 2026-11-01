import 'package:flutter/material.dart';

import '../models/brand_registry.dart';
import '../ui/app_format.dart';

/// The brand's emblem (logo without its name). A brand we have no logo
/// for yet gets a coloured disc with its initials, so "Blu Energy" and
/// "Velox" still look different on the map; no brand at all gets a pump.
/// [stationName] lets a typed name like "Petron Mayapa" still find its
/// brand when none was stored.
Widget brandLogoWidget(
  String brandName,
  double size, {
  String stationName = '',
}) {
  final brand = BrandRegistry.match(brandName, stationName: stationName);
  if (brand != null) return brand.mark(size: size);
  final initials = brandInitials(brandName);
  if (initials.isEmpty) {
    return Icon(
      Icons.local_gas_station_rounded,
      size: size * 0.7,
      color: brandAccent(brandName),
    );
  }
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: brandAccent(brandName),
      shape: BoxShape.circle,
    ),
    child: Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * (initials.length == 1 ? 0.5 : 0.38),
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
  );
}

/// Up to two initials for a brand name: "Blu Energy" → "BE", "Velox" →
/// "V", "RM C Petrol" → "RP". Empty for a blank name.
String brandInitials(String brandName) {
  final words = brandName
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  if (words.length == 1) return words.first[0].toUpperCase();
  return (words.first[0] + words.last[0]).toUpperCase();
}
