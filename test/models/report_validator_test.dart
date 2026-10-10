import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/report_validator.dart';

void main() {
  test('one valid price is enough', () {
    final e = validateReportPrices(regular: '62.50', premium: '', diesel: '');
    expect(e.isEmpty, isTrue);
  });

  test('asks for at least one price when all are blank', () {
    final e = validateReportPrices(regular: '', premium: ' ', diesel: '');
    expect(e.general, 'Enter at least one price');
  });

  test('flags each out-of-range price on its own row', () {
    final e = validateReportPrices(
      regular: '6.25',
      premium: '70',
      diesel: '151',
    );
    expect(e.regular, 'Should be ₱30–₱150');
    expect(e.premium, isNull);
    expect(e.diesel, 'Should be ₱30–₱150');
  });

  test('flags text that is not a number', () {
    final e = validateReportPrices(regular: '6.2.5', premium: '', diesel: '');
    expect(e.regular, 'Enter a number, like 62.50');
  });
}
