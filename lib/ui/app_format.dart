import 'package:flutter/material.dart';

import '../models/brand_registry.dart';

String formatPhp(double value) {
  if (value.isNaN || value.isInfinite) return '₱—';
  if (value <= 0) return '₱—';
  return '₱${value.toStringAsFixed(2)}';
}

String formatPricePerLiter(double value) {
  final money = formatPhp(value);
  if (money == '₱—') return '—';
  return '$money/L';
}

String formatRelativeTime(DateTime dt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(dt);
  if (diff.isNegative) return 'just now';
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// A colour for a brand: the brand's own for the ones we know, else a
/// steady hue picked from the name so the same brand always looks the
/// same. Blank brands get ink.
Color brandAccent(String brand) {
  final b = brand.trim().toLowerCase();
  if (b.isEmpty) return const Color(0xFF111827);
  if (BrandRegistry.findByName(b) case final known?) return known.color;
  if (b.contains('shell')) return const Color(0xFFFFC107);
  if (b.contains('caltex') || b.contains('chevron')) {
    return const Color(0xFF2563EB);
  }
  if (b.contains('petron')) return const Color(0xFFDC2626);
  if (b.contains('seaoil')) return const Color(0xFF7C3AED);
  if (b.contains('unioil')) return const Color(0xFF16A34A);
  if (b.contains('phoenix')) return const Color(0xFFEA580C);
  if (b.contains('jetti')) return const Color(0xFF0EA5E9);
  if (b.contains('blu')) return const Color(0xFF1D4ED8);
  if (b.contains('velox')) return const Color(0xFF0F766E);
  if (b.contains('mobil')) return const Color(0xFFB91C1C);
  if (b.contains('petronas')) return const Color(0xFF0D9488);
  if (b.contains('total')) return const Color(0xFFDC2626);
  // Dark enough for white initials (≈4.5:1) at any hue.
  final hue = b.codeUnits.fold(0, (h, c) => (h * 31 + c) % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.55, 0.36).toColor();
}
