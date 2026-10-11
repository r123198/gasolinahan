import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/brand_registry.dart';
import 'package:gasolinahan/models/report_points_context.dart';

// Sunday Oct 11 2026, 9 AM: this week's price change was Tue Oct 6, 6 AM.
final now = DateTime(2026, 10, 11, 9);
const userLat = 14.2117;
const userLng = 121.1653;

ReportedStationInfo station({
  double lat = 14.2118,
  double lng = 121.1654,
  DateTime? lastUpdated,
}) => ReportedStationInfo(
  latitude: lat,
  longitude: lng,
  lastUpdated: lastUpdated ?? DateTime(2026, 10, 7, 8),
);

const grades = {FuelCategory.regular: 60.0, FuelCategory.diesel: 55.0};

ReportPointsInput input({
  Map<String, double> productPrices = const {},
  Map<FuelCategory, double> gradePrices = grades,
  bool hasPhoto = true,
  double? lat = userLat,
  double? lng = userLng,
  ReportedStationInfo? existing,
  bool isNew = false,
  List<Map<FuelCategory, double>> nearby = const [],
  List<PastReport>? history = const [],
}) => ReportPointsInput(
  stationId: 'petron_mayapa',
  productPrices: productPrices,
  gradePrices: gradePrices,
  hasPhoto: hasPhoto,
  userLat: lat,
  userLng: lng,
  existingStation: isNew ? null : (existing ?? station()),
  nearbyGradePrices: nearby,
  history: history,
  now: now,
);

void main() {
  group('product count', () {
    test('counts priced products', () {
      final c = buildReportContext(
        input(productPrices: const {'XCS': 61, 'Turbo Diesel': 55, 'X': 0}),
      );
      expect(c.productCount, 2);
    });

    test('falls back to priced grades', () {
      expect(buildReportContext(input()).productCount, 2);
    });
  });

  test('photo flag passes through', () {
    expect(buildReportContext(input(hasPhoto: false)).hasPhoto, isFalse);
  });

  group('at the station', () {
    test('within 200 m of a station with coordinates', () {
      expect(buildReportContext(input()).isAtStation, isTrue);
    });

    test('too far from the station', () {
      final far = station(lat: 14.2300, lng: 121.1800);
      expect(buildReportContext(input(existing: far)).isAtStation, isFalse);
    });

    test('a station without coordinates counts as here', () {
      final noCoords = station(lat: 0, lng: 0);
      expect(buildReportContext(input(existing: noCoords)).isAtStation, isTrue);
    });

    test('a new station counts as here', () {
      expect(buildReportContext(input(isNew: true)).isAtStation, isTrue);
    });

    test('unknown user location is not at the station', () {
      expect(
        buildReportContext(input(lat: null, lng: null)).isAtStation,
        false,
      );
      expect(buildReportContext(input(lat: 0, lng: 0)).isAtStation, isFalse);
    });
  });

  group('station freshness', () {
    test('a new station is flagged and nothing else', () {
      final c = buildReportContext(input(isNew: true));
      expect(c.isNewStation, isTrue);
      expect(c.isFirstAfterPriceChange, isFalse);
      expect(c.isConfirmation, isFalse);
    });

    test('last report before Tuesday makes this the first after', () {
      final old = station(lastUpdated: DateTime(2026, 10, 5, 20));
      final c = buildReportContext(input(existing: old));
      expect(c.isFirstAfterPriceChange, isTrue);
      expect(c.isConfirmation, isFalse);
    });

    test('someone already reported today: a confirmation', () {
      final today = station(lastUpdated: DateTime(2026, 10, 11, 7));
      final c = buildReportContext(input(existing: today));
      expect(c.isConfirmation, isTrue);
      expect(c.isFirstAfterPriceChange, isFalse);
    });

    test('reported earlier this week but not today: a normal report', () {
      final c = buildReportContext(input());
      expect(c.isConfirmation, isFalse);
      expect(c.isFirstAfterPriceChange, isFalse);
      expect(c.isNewStation, isFalse);
    });
  });

  group('history', () {
    PastReport past(String stationId, DateTime at, {int points = 6}) =>
        PastReport(stationId: stationId, timestamp: at, pointsAwarded: points);

    test('counts rewarded reports today and spots this station', () {
      final c = buildReportContext(
        input(
          history: [
            past('petron_mayapa', DateTime(2026, 10, 11, 7)),
            past('shell_edsa', DateTime(2026, 10, 11, 8)),
            past('caltex', DateTime(2026, 10, 11, 8), points: 0),
            past('shell_edsa', DateTime(2026, 10, 10, 8)),
          ],
        ),
      );
      expect(c.rewardedReportsToday, 2);
      expect(c.alreadyRewardedStationToday, isTrue);
      expect(c.isFirstReport, isFalse);
    });

    test('first report when nothing was ever rewarded', () {
      final c = buildReportContext(
        input(history: [past('x', DateTime(2026, 10, 1), points: 0)]),
      );
      expect(c.isFirstReport, isTrue);
    });

    test('streak counts earlier weeks with rewarded reports', () {
      final c = buildReportContext(
        input(
          history: [
            past('a', DateTime(2026, 10, 1)), // last week
            past('b', DateTime(2026, 9, 24)), // the week before
          ],
        ),
      );
      expect(c.streakWeeks, 2);
    });

    test('unknown history (offline) assumes nothing', () {
      final c = buildReportContext(input(history: null));
      expect(c.rewardedReportsToday, 0);
      expect(c.alreadyRewardedStationToday, isFalse);
      expect(c.isFirstReport, isFalse);
      expect(c.streakWeeks, 0);
    });
  });

  group('outliers', () {
    const nearby = [
      {FuelCategory.regular: 60.0, FuelCategory.diesel: 55.0},
      {FuelCategory.regular: 61.0, FuelCategory.diesel: 54.0},
      {FuelCategory.regular: 59.0, FuelCategory.diesel: 56.0},
    ];

    test('prices close to the area median are fine', () {
      expect(buildReportContext(input(nearby: nearby)).isOutlier, isFalse);
    });

    test('a price more than 15% off the median is an outlier', () {
      final c = buildReportContext(
        input(gradePrices: const {FuelCategory.regular: 45.0}, nearby: nearby),
      );
      expect(c.isOutlier, isTrue);
    });

    test('fewer than 3 nearby prices cannot judge', () {
      final c = buildReportContext(
        input(
          gradePrices: const {FuelCategory.regular: 45.0},
          nearby: nearby.take(2).toList(),
        ),
      );
      expect(c.isOutlier, isFalse);
    });
  });

  test('pointsReason joins the award lines', () {
    expect(
      describeAward(buildReportContext(input())),
      'Price report +3, 2 prices +2, First report +5',
    );
  });
}
