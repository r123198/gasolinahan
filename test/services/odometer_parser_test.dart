import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/services/odometer_parser.dart';

void main() {
  test('reads a plain odometer number', () {
    expect(parseOdometer(['45231']), 45231);
  });

  test('ignores a trip meter with a decimal', () {
    expect(parseOdometer(['TRIP A', '123.4', '45231']), 45231);
  });

  test('handles thousands separators and a km suffix', () {
    expect(parseOdometer(['45,231 km']), 45231);
    expect(parseOdometer(['45 231 km']), 45231);
  });

  test('prefers the longest number over speed and temperature', () {
    expect(parseOdometer(['80', '28°C', '123456', 'km/h']), 123456);
  });

  test('ignores clock times', () {
    expect(parseOdometer(['10:45', '45231']), 45231);
  });

  test('returns null when nothing looks like an odometer', () {
    expect(parseOdometer(['ABS', '80', 'ECO']), isNull);
    expect(parseOdometer(const []), isNull);
  });

  test('ignores absurd values beyond a million km', () {
    expect(parseOdometer(['99999999']), isNull);
  });
}
