import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/local_account_data.dart';
import '../services/report_writer.dart' show onReportsUploaded;

class AuthViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final LocalAccountData _localData;

  AuthViewModel({FirebaseService? firebaseService, LocalAccountData? localData})
    : _firebaseService = firebaseService ?? FirebaseService(),
      _localData = localData ?? LocalAccountData() {
    // Reports earn points; re-read them so the Account tab stays current.
    _uploadsSub = onReportsUploaded.listen((_) => _refreshAfterUpload());
  }

  late final StreamSubscription<void> _uploadsSub;

  Future<void> _refreshAfterUpload() async {
    if (_currentUser == null) return;
    try {
      await refreshUser();
    } on Exception catch (e) {
      debugPrint('Refreshing points after a report failed: $e');
    }
  }

  @override
  void dispose() {
    _uploadsSub.cancel();
    super.dispose();
  }

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// Never throws: a failed lookup (e.g. offline) leaves the user signed
  /// out so the splash screen can always move on.
  Future<void> checkAuthState() async {
    try {
      final user = await _firebaseService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } on Exception catch (e) {
      debugPrint('checkAuthState failed: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      _currentUser = await _firebaseService.signIn(email, password);
      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    _setLoading(true);
    try {
      _currentUser = await _firebaseService.signUp(name, email, password);
      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshUser() async {
    final user = await _firebaseService.getCurrentUser();
    if (user != null) {
      _currentUser = user;
      notifyListeners();
    }
  }

  Future<void> updateProfileImage(String imagePath) async {
    if (_currentUser == null) return;
    _setLoading(true);
    try {
      final file = File(imagePath);
      final url = await _firebaseService.uploadProfileImage(
        _currentUser!.id,
        file,
      );
      _currentUser = _currentUser!.copyWith(profileImageUrl: url);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update profile image.';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _firebaseService.signOut();
      _currentUser = null;
    } finally {
      _setLoading(false);
    }
  }

  /// Returns null on success, or a message to show the user.
  Future<String?> sendPasswordReset(String email) =>
      _runAccountAction(() => _firebaseService.sendPasswordReset(email));

  Future<String?> updateName(String name) async {
    final user = _currentUser;
    if (user == null) return 'You are signed out. Sign in again.';
    final trimmed = name.trim();
    final error = await _runAccountAction(
      () => _firebaseService.updateName(user.id, trimmed),
    );
    if (error == null) {
      _currentUser = user.copyWith(name: trimmed);
      notifyListeners();
    }
    return error;
  }

  Future<String?> changePassword(String current, String next) =>
      _runAccountAction(() => _firebaseService.changePassword(current, next));

  /// Deletes the account in the cloud, then this phone's copy of the
  /// user's data. Returns null on success, or a message to show the user.
  Future<String?> deleteAccount(String password) async {
    final user = _currentUser;
    if (user == null) return 'You are signed out. Sign in again.';
    final error = await _runAccountAction(
      () => _firebaseService.deleteAccount(password),
    );
    if (error != null) return error;
    _currentUser = null;
    notifyListeners();
    try {
      await _localData.wipe(uid: user.id);
    } on Exception catch (e) {
      // The account is already gone; leftovers here can't be tied back to
      // it, so the deletion still counts as done.
      debugPrint('Local data wipe after account deletion failed: $e');
    }
    return null;
  }

  Future<String?> _runAccountAction(Future<void> Function() action) async {
    _setLoading(true);
    try {
      await action();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } on FirebaseException catch (e) {
      debugPrint('Account action failed: ${e.code} ${e.message}');
      return 'Could not save. Check your connection and try again.';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  String _mapAuthError(String code) {
    return switch (code) {
      'user-not-found' => 'No account found with this email.',
      'wrong-password' => 'Incorrect password.',
      'invalid-credential' => 'Invalid email or password.',
      'email-already-in-use' => 'An account with this email already exists.',
      'weak-password' => 'Choose a stronger password.',
      'requires-recent-login' => 'Please sign out and sign in again first.',
      'invalid-email' => 'Please enter a valid email address.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' => 'No internet connection.',
      _ => 'Authentication failed. Please try again.',
    };
  }
}
