import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/ui/number_input_formatter.dart';

String type(TextInputFormatter f, String old, String next) => f
    .formatEditUpdate(
      TextEditingValue(text: old),
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      ),
    )
    .text;

void main() {
  final money = numberInputFormatter();
  final whole = numberInputFormatter(decimal: false);

  test('accepts digits, commas and one decimal point', () {
    expect(type(money, '1,25', '1,250.5'), '1,250.5');
  });

  test('blocks a second decimal point', () {
    expect(type(money, '62.5', '62.5.'), '62.5');
  });

  test('blocks more than two decimal places', () {
    expect(type(money, '62.50', '62.505'), '62.50');
  });

  test('blocks letters', () {
    expect(type(money, '62', '62a'), '62');
  });

  test('whole-number fields reject the decimal point', () {
    expect(type(whole, '9129', '9129.'), '9129');
  });
}
