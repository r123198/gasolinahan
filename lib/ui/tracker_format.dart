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

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _group(int whole) => whole.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

/// "Sep 27, 2026"
String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "Today", "Yesterday" or "Sep 27, 2026" — for the date chip in forms.
String formatDayLabel(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return formatDate(d);
}

/// "₱1,250.50" — exact peso amount with centavos.
String formatPesosExact(double value) {
  if (value.isNaN || value.isInfinite || value <= 0) return '₱0.00';
  final cents = (value * 100).round();
  final centavos = (cents % 100).toString().padLeft(2, '0');
  return '₱${_group(cents ~/ 100)}.$centavos';
}

/// "9.213 L"
String formatLiters(double liters) => '${liters.toStringAsFixed(3)} L';

/// "+63 km"
String formatKmDelta(double km) => '+${_group(km.round())} km';
