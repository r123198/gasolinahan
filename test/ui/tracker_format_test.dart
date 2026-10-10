import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/ui/tracker_format.dart';

void main() {
  test('formatDate shows short month, day and year', () {
    expect(formatDate(DateTime(2026, 9, 27)), 'Sep 27, 2026');
  });

  test('formatDayLabel names today and yesterday', () {
    final now = DateTime(2026, 10, 10, 17);
    expect(formatDayLabel(DateTime(2026, 10, 10, 8), now: now), 'Today');
    expect(formatDayLabel(DateTime(2026, 10, 9, 23), now: now), 'Yesterday');
    expect(formatDayLabel(DateTime(2026, 9, 27), now: now), 'Sep 27, 2026');
  });

  test('formatPesosExact keeps centavos and groups thousands', () {
    expect(formatPesosExact(755.47), '₱755.47');
    expect(formatPesosExact(1250.5), '₱1,250.50');
  });

  test('formatLiters and formatKmDelta', () {
    expect(formatLiters(9.2134), '9.213 L');
    expect(formatKmDelta(1063.4), '+1,063 km');
  });
}
