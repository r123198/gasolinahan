const _maxOdometerKm = 1000000;

// Either a number grouped by commas/spaces ("45,231", "45 231"), or a plain
// run of 4-7 digits. Rejects decimals (trip meters) and times ("10:45").
final _candidate = RegExp(
  r'(?<![\d.:,])\d{1,3}(?:[, ]\d{3})+(?![\d.:])|(?<![\d.:,])\d{4,7}(?![\d.:])',
);

/// Picks the odometer reading out of text recognised from a dashboard photo.
/// Returns null when nothing plausible is found.
double? parseOdometer(List<String> lines) {
  int? best;
  var bestDigits = 0;
  for (final line in lines) {
    for (final match in _candidate.allMatches(line)) {
      final digits = match.group(0)!.replaceAll(RegExp(r'[, ]'), '');
      final value = int.tryParse(digits);
      if (value == null || value <= 0 || value >= _maxOdometerKm) continue;
      final isBetter =
          digits.length > bestDigits ||
          (digits.length == bestDigits && value > (best ?? 0));
      if (isBetter) {
        best = value;
        bestDigits = digits.length;
      }
    }
  }
  return best?.toDouble();
}
