import 'fill_up_photo_store.dart';
import 'offline_database_service.dart';

/// Everything Gasolinahan keeps about its user on this phone: fill-ups and
/// their photos, recorded trips, and price reports waiting to sync.
class LocalAccountData {
  /// Removes it all, for when the account is deleted.
  Future<void> wipe() async {
    await OfflineDatabaseService.clearPersonalData();
    await FillUpPhotoStore().discardAll();
  }
}
