import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/models/fill_up_validator.dart';

FillUp existing(double odo, DateTime at) => FillUp(
  stationId: 's',
  stationName: 'Shell',
  brand: 'Shell',
  fuelType: 'regular',
  amountSpent: 500,
  odometerKm: odo,
  timestamp: at,
);

final now = DateTime(2026, 10, 10, 17, 30);

FillUpDraft draft({
  String? station = 'Shell EDSA',
  String amount = '755.47',
  String price = '82.00',
  String odometer = '9129',
  DateTime? date,
  String notes = '',
}) => FillUpDraft(
  stationName: station,
  amountText: amount,
  pricePerLiterText: price,
  odometerText: odometer,
  date: date ?? now,
  notes: notes,
);

void main() {
  FillUpErrors check(FillUpDraft d, [List<FillUp> others = const []]) =>
      validateFillUp(d, others: others, now: now);

  test('a complete, sensible fill-up has no errors', () {
    expect(check(draft()).isEmpty, isTrue);
  });

  test('requires a station', () {
    expect(check(draft(station: ' ')).station, 'Choose or type a station');
  });

  test('requires a positive amount', () {
    expect(check(draft(amount: '')).amount, 'Enter how much you paid');
    expect(check(draft(amount: '0')).amount, 'Enter how much you paid');
  });

  test('rejects text that is not a number', () {
    expect(check(draft(amount: '12a')).amount, 'Enter a number, like 755.47');
  });

  test('accepts thousands separators', () {
    expect(check(draft(amount: '1,250.50')).amount, isNull);
  });

  test('keeps price per liter in a believable range', () {
    expect(
      check(draft(price: '8.2')).pricePerLiter,
      'Price per liter should be between ₱30 and ₱200',
    );
  });

  test('flags an amount that would be more than a tank holds', () {
    expect(
      check(draft(amount: '20000', price: '80')).amount,
      "That's 250 L at this price. Check the amount and price.",
    );
  });

  test('odometer must be above the previous fill-up', () {
    final errors = check(draft(odometer: '9000'), [
      existing(9066, DateTime(2026, 9, 26)),
    ]);
    expect(errors.odometer, 'Should be more than 9,066 km (your last fill-up)');
  });

  test('backdated odometer must be below the next fill-up', () {
    final errors = check(draft(odometer: '9200', date: DateTime(2026, 9, 27)), [
      existing(9066, DateTime(2026, 9, 26)),
      existing(9150, DateTime(2026, 9, 28)),
    ]);
    expect(errors.odometer, 'Should be less than 9,150 km (your next fill-up)');
  });

  test('date cannot be in the future', () {
    expect(
      check(draft(date: now.add(const Duration(days: 1)))).date,
      "Date can't be in the future",
    );
  });

  test('limits notes length', () {
    expect(
      check(draft(notes: 'x' * 201)).notes,
      'Keep notes under 200 characters',
    );
  });

  test('parses the values for saving', () {
    final d = draft(amount: '1,000', price: '80');
    expect(d.amount, 1000);
    expect(d.pricePerLiter, 80);
    expect(d.liters, closeTo(12.5, 0.0001));
    expect(d.odometer, 9129);
  });
}
