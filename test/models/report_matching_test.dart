import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/brand_registry.dart';
import 'package:gasolinahan/models/price_board_parser.dart';
import 'package:gasolinahan/models/report_matching.dart';
import 'package:gasolinahan/models/report_model.dart';
import 'package:gasolinahan/models/station_model.dart';

StationModel _station(String brand, {String name = ''}) => StationModel(
  id: 's',
  name: name,
  brand: brand,
  address: '',
  latitude: 14.6,
  longitude: 121.0,
  regularPrice: 0,
  premiumPrice: 0,
  dieselPrice: 0,
  lastUpdated: DateTime(2026),
);

ReportModel _sent(String id, {int points = 5}) => ReportModel(
  id: id,
  userId: 'uid-1',
  stationId: 'st-$id',
  reportedRegularPrice: 60,
  reportedPremiumPrice: 0,
  reportedDieselPrice: 0,
  timestamp: DateTime(2026, 10, 1),
  pointsAwarded: points,
  status: 'accepted',
);

Map<String, dynamic> _queued(int id, {String? remoteId}) => {
  'id': id,
  'stationId': 'st-q$id',
  'timestamp': '2026-10-02T09:00:00.000',
  'pointsAwarded': 4,
  'isPending': 0,
  'remoteId': remoteId,
};

void main() {
  group('brandFits', () {
    final shell = BrandRegistry.findByName('Shell');
    final petron = BrandRegistry.findByName('Petron');

    test('matches a station of the board brand', () {
      expect(brandFits(shell, _station('Shell')), isTrue);
    });

    test('rejects a station of another brand', () {
      expect(brandFits(petron, _station('Shell')), isFalse);
    });

    test('accepts when either brand is unknown', () {
      expect(brandFits(null, _station('Shell')), isTrue);
      expect(brandFits(shell, _station('')), isTrue);
    });
  });

  group('mergeReportHistory', () {
    test('adds queued reports to the sent ones', () {
      final history = mergeReportHistory(
        [_sent('a')],
        [_queued(1)],
        uid: 'uid-1',
      );

      expect(history.map((p) => p.stationId), ['st-a', 'st-q1']);
      expect(history.last.pointsAwarded, 4);
    });

    test('counts a queued report that already landed once', () {
      final history = mergeReportHistory(
        [_sent('r1')],
        [_queued(1, remoteId: 'r1')],
        uid: 'uid-1',
      );

      expect(history, hasLength(1));
    });
  });

  test('a price board needs fuel words and prices', () {
    expect(looksLikePriceBoard('PETRON XCS 61.50 Diesel 55.20'), isTrue);
    expect(looksLikePriceBoard('Grocery list: eggs 12.50'), isFalse);
  });
}
