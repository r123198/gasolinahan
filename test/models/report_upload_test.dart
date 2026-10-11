import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/report_upload.dart';
import 'package:gasolinahan/services/geo.dart';

Map<String, dynamic> _row({
  int id = 7,
  int isPending = 0,
  String? remoteId,
  int points = 6,
}) => {
  'id': id,
  'userId': 'uid-1',
  'stationId': 'st-1',
  'stationName': 'Petron EDSA',
  'brand': 'Petron',
  'regularPrice': 61.5,
  'premiumPrice': 0.0,
  'dieselPrice': 55.0,
  'latitude': 14.6,
  'longitude': 121.0,
  'timestamp': '2026-10-01T08:30:00.000',
  'productPrices': '{"XCS": 61.5}',
  'pointsAwarded': points,
  'pointsReason': 'Price report +3',
  'isPending': isPending,
  'remoteId': remoteId,
};

void main() {
  group('ReportUpload.fromPendingRow', () {
    test('an unusual price syncs as pending with no points', () {
      final upload = ReportUpload.fromPendingRow(
        _row(isPending: 1),
        uid: 'uid-1',
      );

      expect(upload.reportFields()['status'], 'pending');
      expect(upload.reportFields()['pointsAwarded'], 0);
      expect(upload.awardedPoints, 0);
    });

    test('an ordinary row syncs accepted with its points', () {
      final upload = ReportUpload.fromPendingRow(_row(), uid: 'uid-1');

      expect(upload.reportFields()['status'], 'accepted');
      expect(upload.awardedPoints, 6);
      expect(upload.productPrices, {'XCS': 61.5});
      expect(upload.timestamp, DateTime(2026, 10, 1, 8, 30));
    });

    test('reuses the id of a timed-out online attempt', () {
      final upload = ReportUpload.fromPendingRow(
        _row(remoteId: 'abc123'),
        uid: 'uid-1',
      );

      expect(upload.reportId, 'abc123');
    });

    test('derives the same id for the same row every time', () {
      final a = pendingReportDocId(_row(), uid: 'uid-1');
      final b = pendingReportDocId(_row(), uid: 'uid-1');

      expect(a, b);
      expect(a, startsWith('pending_uid-1_7_'));
      expect(a, isNot(pendingReportDocId(_row(id: 8), uid: 'uid-1')));
    });
  });

  group('stationFields', () {
    final upload = ReportUpload.fromPendingRow(_row(), uid: 'uid-1');

    test('a known station keeps its name, brand and position', () {
      final fields = upload.stationFields(stationExists: true);

      expect(fields.keys, containsAll(['regularPrice', 'dieselPrice']));
      expect(fields, isNot(contains('name')));
      expect(fields, isNot(contains('brand')));
      expect(fields, isNot(contains('latitude')));
      expect(fields, isNot(contains('premiumPrice')));
    });

    test('a new station is described by the report', () {
      final fields = upload.stationFields(stationExists: false);

      expect(fields['name'], 'Petron EDSA');
      expect(fields['brand'], 'Petron');
      expect(fields['latitude'], 14.6);
    });
  });

  group('GeoBox.around', () {
    final box = GeoBox.around(14.6, 121.0, 5000);

    test('holds points within the radius', () {
      expect(box.contains(14.6, 121.0), isTrue);
      // ~4.5 km east and north.
      expect(box.contains(14.6, 121.0415), isTrue);
      expect(box.contains(14.64, 121.0), isTrue);
    });

    test('leaves out points beyond it', () {
      expect(box.contains(14.7, 121.0), isFalse);
      expect(box.contains(14.6, 121.06), isFalse);
    });

    test('reaches the full radius along both axes', () {
      expect(
        haversineMeters(14.6, 121.0, box.maxLat, 121.0),
        greaterThanOrEqualTo(4990),
      );
      expect(
        haversineMeters(14.6, 121.0, 14.6, box.maxLng),
        greaterThanOrEqualTo(4990),
      );
    });
  });
}
