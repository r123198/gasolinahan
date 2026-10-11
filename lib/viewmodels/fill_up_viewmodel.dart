import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/fill_up_log.dart';
import '../models/fill_up_model.dart';
import '../models/fill_up_points.dart';
import '../models/fill_up_sync.dart';
import '../models/points_rules.dart';
import '../models/station_summary.dart';
import '../services/fill_up_photo_store.dart';
import '../services/fill_up_remote.dart';
import '../services/firebase_service.dart';
import '../services/fill_up_service.dart';

/// The fill-up log. Reads and writes go to the on-device database first, so
/// the app works offline; signed-in users' changes are also mirrored to the
/// cloud (see [FillUpRemote]) and merged back in on [load], so the log
/// follows them to other phones.
/// Adds (or takes back, when negative) points for [uid].
typedef PointsAwarder =
    Future<void> Function(String uid, int points, String reason, String source);

class FillUpViewModel extends ChangeNotifier {
  final FillUpService _service;
  final FillUpPhotoStore _photos;
  final FillUpRemote? _injectedRemote;
  final String? Function() _currentUserId;
  final PointsAwarder? _injectedAwarder;

  FillUpViewModel({
    FillUpService? service,
    FillUpPhotoStore? photos,
    FillUpRemote? remote,
    String? Function()? currentUserId,
    PointsAwarder? awardPoints,
  }) : _service = service ?? FillUpService(),
       _photos = photos ?? FillUpPhotoStore(),
       _injectedRemote = remote,
       _currentUserId = currentUserId ?? _firebaseUserId,
       _injectedAwarder = awardPoints;

  PointsAwarder get _awardPoints =>
      _injectedAwarder ??
      (uid, points, reason, source) => FirebaseService().awardPoints(
        uid,
        points,
        reason: reason,
        source: source,
      );

  PointsAward? _lastAward;

  /// What the most recent [add] earned (null when signed out).
  PointsAward? get lastAward => _lastAward;

  int _pointsVersion = 0;

  /// Bumps each time a points change reaches the server, so screens showing
  /// the balance know to re-read it.
  int get pointsVersion => _pointsVersion;

  static String? _firebaseUserId() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } on FirebaseException {
      return null; // Firebase not set up (tests, or before init)
    }
  }

  // Created on first use so signed-out sessions never touch Firestore.
  FillUpRemote? _lazyRemote;
  FillUpRemote get _remote =>
      _injectedRemote ?? (_lazyRemote ??= FirestoreFillUpRemote());

  List<FillUp> _fillUps = const [];
  bool _isLoading = true;
  String? _errorMessage;

  List<FillUp> get fillUps => _fillUps;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<StationSummary> get summaries => StationSummary.summarize(_fillUps);
  TrackerTotals get totals => TrackerTotals.from(_fillUps);
  FillUpLog get log => FillUpLog.build(_fillUps);

  /// The most recent fill-up, used to pre-fill the next one.
  FillUp? get latest => _fillUps.isEmpty
      ? null
      : _fillUps.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);

  /// Last price paid for [fuelType] at [stationId], if any.
  double? lastPriceAt(String stationId, String fuelType) {
    final matches =
        _fillUps
            .where(
              (f) =>
                  f.stationId == stationId &&
                  f.fuelType == fuelType &&
                  f.effectivePricePerLiter != null,
            )
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matches.isEmpty ? null : matches.first.effectivePricePerLiter;
  }

  /// Highest odometer reading logged so far, used to sanity-check new entries.
  double? get lastOdometer => _fillUps.isEmpty
      ? null
      : _fillUps.map((f) => f.odometerKm).reduce((a, b) => a > b ? a : b);

  List<FillUp> historyFor(String key) =>
      StationSummary.historyFor(key, _fillUps);

  Future<void>? _loading;

  /// Shows the local log at once, then merges in the cloud copy. Calls made
  /// while a load is running join it: two syncs planned from the same
  /// snapshot would insert and upload every row twice.
  Future<void> load() =>
      _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final uid = _currentUserId();
    try {
      _fillUps = await _service.getAll(ownerUid: uid);
    } catch (e) {
      _errorMessage = 'Could not load your fill-ups.';
      if (kDebugMode) print('Fill-up load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    if (uid != null && _errorMessage == null) await _syncWithCloud(uid);
  }

  /// Best-effort: offline or failing, the local log simply stays as it is.
  Future<void> _syncWithCloud(String uid) async {
    try {
      final remote = await _remote.fetchAll(uid);
      final plan = planFillUpSync(local: _fillUps, remote: remote);
      if (plan.isEmpty) return;
      for (final f in plan.insertLocal) {
        await _service.insert(f.copyWith(ownerUid: uid));
      }
      for (final f in plan.updateLocal) {
        await _service.update(f.copyWith(ownerUid: uid));
      }
      for (final f in plan.deleteLocal) {
        await _service.delete(f.id!);
        await _photos.discard(f.photoPaths);
      }
      for (final f in plan.upload) {
        final claimed = _stamped(f, uid, touch: false);
        await _service.update(claimed);
        _send(uid, claimed);
      }
      _fillUps = await _service.getAll(ownerUid: uid);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Fill-up sync skipped: $e');
    }
  }

  /// Gives [f] its owner and cloud id, and (when [touch]) marks it edited now.
  FillUp _stamped(FillUp f, String uid, {bool touch = true}) => f.copyWith(
    ownerUid: f.ownerUid ?? uid,
    remoteId: f.remoteId ?? _remote.newId(uid),
    updatedAt: touch ? DateTime.now() : (f.updatedAt ?? f.timestamp),
  );

  static String _describe(PointsAward award) =>
      award.lines.map((l) => '${l.label} +${l.points}').join(', ');

  void _grant(String uid, int points, String reason, String? remoteId) {
    if (points == 0) return;
    unawaited(
      _awardPoints(uid, points, reason, 'fill-up:${remoteId ?? 'local'}')
          .then((_) {
            _pointsVersion++;
            notifyListeners();
          })
          .catchError((Object e) {
            if (kDebugMode) print('Points award failed: $e');
          }),
    );
  }

  /// Queues the upload without waiting: offline, Firestore holds it until
  /// the connection is back.
  void _send(String uid, FillUp f) {
    unawaited(
      _remote.save(uid, f).catchError((Object e) {
        if (kDebugMode) print('Fill-up upload failed: $e');
      }),
    );
  }

  /// Returns true when the fill-up was saved.
  Future<bool> add(FillUp fillUp) async {
    final uid = _currentUserId();
    _lastAward = null;
    try {
      var toSave = uid == null
          ? fillUp.copyWith(updatedAt: DateTime.now())
          : _stamped(fillUp, uid);
      final award = uid == null
          ? null
          : pointsForFillUp(
              fillUpPointsContext(newFill: toSave, history: _fillUps),
            );
      if (award != null) toSave = toSave.copyWith(pointsAwarded: award.points);
      final id = await _service.insert(toSave);
      if (uid != null) _send(uid, toSave.copyWith(id: id));
      if (uid != null && award != null) {
        _lastAward = award;
        _grant(uid, award.points, _describe(award), toSave.remoteId);
      }
      _fillUps = await _service.getAll(ownerUid: uid);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Could not save this fill-up.';
      if (kDebugMode) print('Fill-up save error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Saves edits to an existing fill-up. Returns true when saved.
  Future<bool> update(
    FillUp fillUp, {
    Iterable<String> removedPhotos = const [],
  }) async {
    final uid = _currentUserId();
    // The form rebuilds the fill-up from scratch, so carry over its sync
    // identity from the stored copy.
    final existing = _fillUps.where((f) => f.id == fillUp.id).firstOrNull;
    final carried = fillUp.copyWith(
      remoteId: existing?.remoteId,
      ownerUid: existing?.ownerUid,
      pointsAwarded: existing?.pointsAwarded,
    );
    try {
      final toSave = uid == null
          ? carried.copyWith(updatedAt: DateTime.now())
          : _stamped(carried, uid);
      await _service.update(toSave);
      if (uid != null) _send(uid, toSave);
      _fillUps = await _service.getAll(ownerUid: uid);
      _errorMessage = null;
      notifyListeners();
      await _photos.discard(removedPhotos);
      return true;
    } catch (e) {
      _errorMessage = 'Could not save your changes.';
      if (kDebugMode) print('Fill-up update error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> remove(FillUp fillUp) async {
    final id = fillUp.id;
    if (id == null) return;
    try {
      await _service.delete(id);
      _fillUps = _fillUps.where((f) => f.id != id).toList();
      _errorMessage = null;
      await _photos.discard(fillUp.photoPaths);
      final uid = _currentUserId();
      final remoteId = fillUp.remoteId;
      if (uid != null && fillUp.pointsAwarded > 0) {
        // Deleting returns the points, so add-and-delete can't farm them.
        _grant(uid, -fillUp.pointsAwarded, 'Fill-up deleted', remoteId);
      }
      if (uid != null && remoteId != null) {
        unawaited(
          _remote.delete(uid, remoteId).catchError((Object e) {
            if (kDebugMode) print('Fill-up cloud delete failed: $e');
          }),
        );
      }
    } catch (e) {
      _errorMessage = 'Could not delete this fill-up.';
      if (kDebugMode) print('Fill-up delete error: $e');
    }
    notifyListeners();
  }
}
