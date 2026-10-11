import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/fill_up_model.dart';
import 'package:gasolinahan/models/fill_up_sync.dart';

FillUp fill({
  int? id,
  String? remoteId,
  double odo = 1000,
  DateTime? updatedAt,
  List<String> photos = const [],
}) => FillUp(
  id: id,
  remoteId: remoteId,
  stationId: 's',
  stationName: 'Shell',
  brand: 'Shell',
  fuelType: 'regular',
  amountSpent: 500,
  odometerKm: odo,
  timestamp: DateTime(2026, 10, 1),
  updatedAt: updatedAt,
  photoPaths: photos,
);

void main() {
  final older = DateTime(2026, 10, 1, 8);
  final newer = DateTime(2026, 10, 2, 8);

  test('nothing to do when both sides match', () {
    final plan = planFillUpSync(
      local: [fill(id: 1, remoteId: 'a', updatedAt: older)],
      remote: [fill(remoteId: 'a', updatedAt: older)],
    );
    expect(plan.isEmpty, isTrue);
  });

  test('downloads fill-ups logged on another device', () {
    final plan = planFillUpSync(
      local: const [],
      remote: [fill(remoteId: 'a', updatedAt: older)],
    );
    expect(plan.insertLocal.map((f) => f.remoteId), ['a']);
  });

  test('uploads old local-only fill-ups that were never synced', () {
    final plan = planFillUpSync(local: [fill(id: 1)], remote: const []);
    expect(plan.upload.map((f) => f.id), [1]);
  });

  test('a newer edit in the cloud replaces the local copy, keeping photos', () {
    final plan = planFillUpSync(
      local: [
        fill(id: 1, remoteId: 'a', updatedAt: older, photos: const ['/p.jpg']),
      ],
      remote: [fill(remoteId: 'a', odo: 1200, updatedAt: newer)],
    );
    final updated = plan.updateLocal.single;
    expect(updated.id, 1);
    expect(updated.odometerKm, 1200);
    expect(updated.photoPaths, ['/p.jpg']);
  });

  test('a newer local edit is uploaded', () {
    final plan = planFillUpSync(
      local: [fill(id: 1, remoteId: 'a', odo: 1300, updatedAt: newer)],
      remote: [fill(remoteId: 'a', updatedAt: older)],
    );
    expect(plan.upload.single.odometerKm, 1300);
    expect(plan.updateLocal, isEmpty);
  });

  test('a fill-up deleted on another device is deleted here', () {
    final plan = planFillUpSync(
      local: [fill(id: 1, remoteId: 'gone', updatedAt: older)],
      remote: const [],
    );
    expect(plan.deleteLocal.map((f) => f.id), [1]);
  });
}
