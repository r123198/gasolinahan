import 'fill_up_model.dart';

const minPricePerLiter = 30.0;
const maxPricePerLiter = 200.0;
const maxLitersPerFill = 200.0;
const maxAmountPerFill = 100000.0;
const maxOdometerKm = 2000000.0;
const maxNotesLength = 200;
const maxPhotosPerFill = 5;

/// Raw form input for a fill-up, before validation.
class FillUpDraft {
  final String? stationName;
  final String amountText;
  final String pricePerLiterText;
  final String odometerText;
  final DateTime date;
  final String notes;

  const FillUpDraft({
    required this.stationName,
    required this.amountText,
    required this.pricePerLiterText,
    required this.odometerText,
    required this.date,
    this.notes = '',
  });

  double? get amount => parseNumber(amountText);
  double? get pricePerLiter => parseNumber(pricePerLiterText);
  double? get odometer => parseNumber(odometerText);

  /// Liters bought, worked out from what was paid and the pump price.
  double? get liters {
    final a = amount;
    final p = pricePerLiter;
    if (a == null || p == null || a <= 0 || p <= 0) return null;
    return a / p;
  }
}

/// Parses "1,250.50" style input; null when it isn't a number.
double? parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', ''));

/// One message per field; null means the field is fine.
class FillUpErrors {
  final String? station;
  final String? amount;
  final String? pricePerLiter;
  final String? odometer;
  final String? date;
  final String? notes;

  const FillUpErrors({
    this.station,
    this.amount,
    this.pricePerLiter,
    this.odometer,
    this.date,
    this.notes,
  });

  bool get isEmpty =>
      station == null &&
      amount == null &&
      pricePerLiter == null &&
      odometer == null &&
      date == null &&
      notes == null;
}

/// Checks a draft against the user's other fill-ups ([others] must not
/// include the one being edited).
FillUpErrors validateFillUp(
  FillUpDraft draft, {
  required List<FillUp> others,
  required DateTime now,
}) {
  return FillUpErrors(
    station: (draft.stationName?.trim().isEmpty ?? true)
        ? 'Choose or type a station'
        : null,
    amount: _amountError(draft),
    pricePerLiter: _priceError(draft.pricePerLiterText),
    odometer: _odometerError(draft, others),
    date: draft.date.isAfter(now.add(const Duration(minutes: 1)))
        ? "Date can't be in the future"
        : null,
    notes: draft.notes.length > maxNotesLength
        ? 'Keep notes under $maxNotesLength characters'
        : null,
  );
}

String? _amountError(FillUpDraft draft) {
  final text = draft.amountText.trim();
  final amount = parseNumber(text);
  if (text.isEmpty || amount == 0) return 'Enter how much you paid';
  if (amount == null) return 'Enter a number, like 755.47';
  if (amount < 0) return 'Enter how much you paid';
  if (amount > maxAmountPerFill) return "That's over ₱100,000. Check it.";
  final liters = draft.liters;
  if (liters != null && liters > maxLitersPerFill) {
    return "That's ${liters.round()} L at this price. "
        'Check the amount and price.';
  }
  return null;
}

String? _priceError(String text) {
  if (text.trim().isEmpty) return 'Enter the price per liter';
  final price = parseNumber(text);
  if (price == null) return 'Enter a number, like 82.50';
  if (price < minPricePerLiter || price > maxPricePerLiter) {
    return 'Price per liter should be between ₱30 and ₱200';
  }
  return null;
}

String? _odometerError(FillUpDraft draft, List<FillUp> others) {
  final text = draft.odometerText.trim();
  final odometer = parseNumber(text);
  if (text.isEmpty || odometer == 0) return 'Enter your odometer reading';
  if (odometer == null) return 'Enter a number, like 9129';
  if (odometer < 0) return 'Enter your odometer reading';
  if (odometer > maxOdometerKm) return 'That reading looks too high';

  FillUp? previous;
  FillUp? next;
  for (final f in others) {
    if (!f.timestamp.isAfter(draft.date)) {
      if (previous == null || f.timestamp.isAfter(previous.timestamp)) {
        previous = f;
      }
    } else if (next == null || f.timestamp.isBefore(next.timestamp)) {
      next = f;
    }
  }
  if (previous != null && odometer <= previous.odometerKm) {
    final which = next == null ? 'last' : 'previous';
    return 'Should be more than ${_km(previous.odometerKm)} '
        '(your $which fill-up)';
  }
  if (next != null && odometer >= next.odometerKm) {
    return 'Should be less than ${_km(next.odometerKm)} (your next fill-up)';
  }
  return null;
}

String _km(double km) {
  final digits = km.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$digits km';
}
