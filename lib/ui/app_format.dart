import 'package:flutter/material.dart';

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

Color brandAccent(String brand) {
  final b = brand.trim().toLowerCase();
  if (b.contains('shell')) return const Color(0xFFFFC107);
  if (b.contains('caltex') || b.contains('chevron')) {
    return const Color(0xFF2563EB);
  }
  if (b.contains('petron')) return const Color(0xFFDC2626);
  if (b.contains('seaoil')) return const Color(0xFF7C3AED);
  if (b.contains('unioil')) return const Color(0xFF16A34A);
  return const Color(0xFF111827);
}
