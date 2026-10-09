import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class ProfileViewModel extends ChangeNotifier {
  // We'll leave the declaration out because we can just initialize locally
  // or use AuthViewModel state instead if we want to bypass fetching.

  // Here we would normally fetch the user profile dynamically
  // but since our AuthViewModel holds the user state, we might
  // just want to share that. For demo purposes, we can
  // fetch it similarly or pass the data in.

  UserModel? _profileData;
  bool _isLoading = false;

  UserModel? get profileData => _profileData;
  bool get isLoading => _isLoading;

  Future<void> fetchProfileData(String userId) async {
    _isLoading = true;
    notifyListeners();

    // Simulate fetching user data from Firestore using our stub
    await Future.delayed(const Duration(milliseconds: 500));
    _profileData = UserModel(
      id: userId,
      name: 'Alex Driver',
      email: 'alex@example.com',
      profileImageUrl: '',
      joinDate: '2021',
      subscriptionTier: 'GASOLINAHAN GOLD',
      reportsCount: 42,
      points: 1200,
      amountSaved: 15.0,
    );

    _isLoading = false;
    notifyListeners();
  }
}
