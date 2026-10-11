import 'brand_registry.dart';
import 'report_model.dart';
import 'report_points_context.dart';
import 'report_upload.dart';
import 'station_model.dart';

/// Whether [station] can be the one on a board of [boardBrand]: same brand,
/// or either side unknown. Auto-matching a nearby station of another brand
/// would file the prices under the wrong station.
bool brandFits(BrandInfo? boardBrand, StationModel station) {
  if (boardBrand == null) return true;
  final stationBrand = BrandRegistry.match(
    station.brand,
    stationName: station.name,
  );
  return stationBrand == null || stationBrand.name == boardBrand.name;
}

/// The user's report history for points: [sent] reports plus [queued]
/// pending_reports rows not yet uploaded. A queued row whose report id is
/// already among [sent] (a slow send that landed after all) counts once.
List<PastReport> mergeReportHistory(
  List<ReportModel> sent,
  List<Map<String, dynamic>> queued, {
  required String uid,
}) {
  final sentIds = {for (final r in sent) r.id};
  return [
    for (final r in sent)
      PastReport(
        stationId: r.stationId,
        timestamp: r.timestamp,
        pointsAwarded: r.pointsAwarded,
      ),
    for (final row in queued)
      if (ReportUpload.fromPendingRow(row, uid: uid) case final upload
          when !sentIds.contains(upload.reportId))
        upload.toPastReport(),
  ];
}
