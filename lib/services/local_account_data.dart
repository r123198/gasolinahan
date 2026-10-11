import 'fill_up_photo_store.dart';
import 'offline_database_service.dart';

/// Everything Gasolinahan keeps about its user on this phone: fill-ups and
/// their photos, recorded trips, and price reports waiting to sync.
class LocalAccountData {
  /// Removes [uid]'s copy of it, for when that account is deleted. Other
  /// accounts used on this phone keep theirs.
  Future<void> wipe({required String uid}) async {
    final photos = await OfflineDatabaseService.clearPersonalData(uid: uid);
    await FillUpPhotoStore().discard(photos);
  }
}
