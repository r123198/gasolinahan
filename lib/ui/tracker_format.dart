String formatKm(double km) {
  if (km <= 0) return '—';
  final rounded = km.round();
  final digits = rounded.toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$grouped km';
}

String formatPesos(double value) {
  if (value.isNaN || value.isInfinite || value <= 0) return '₱0';
  final whole = value.round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
  return '₱$whole';
}

String formatCostPerKm(double? value) {
  if (value == null || value <= 0) return '—';
  return '₱${value.toStringAsFixed(2)}/km';
}

String formatKmShort(double km) => '${km.toStringAsFixed(1)} km';

String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  return hours > 0 ? '${hours}h ${minutes}m' : '${d.inMinutes}m';
}
