import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/user_model.dart';
import 'package:gasolinahan/services/firebase_service.dart';
import 'package:gasolinahan/services/local_account_data.dart';
import 'package:gasolinahan/viewmodels/auth_viewmodel.dart';

final _user = UserModel(
  id: 'uid-1',
  name: 'Juan',
  email: 'juan@gasolinahan.app',
  profileImageUrl: '',
  joinDate: '2026',
  subscriptionTier: 'GASOLINAHAN FREE',
  reportsCount: 0,
  points: 0,
  amountSaved: 0,
);

/// Records delete calls; throws [deleteError] when set.
class FakeFirebaseService implements FirebaseService {
  final deletedWith = <String>[];
  Exception? deleteError;

  @override
  Future<UserModel> signIn(String email, String password) async => _user;

  @override
  Future<void> deleteAccount(String password) async {
    deletedWith.add(password);
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocalAccountData implements LocalAccountData {
  var wipes = 0;
  final wipedUids = <String>[];
  Exception? wipeError;

  @override
  Future<void> wipe({required String uid}) async {
    wipes++;
    wipedUids.add(uid);
    final error = wipeError;
    if (error != null) throw error;
  }
}

void main() {
  late FakeFirebaseService firebase;
  late FakeLocalAccountData local;
  late AuthViewModel auth;

  setUp(() async {
    firebase = FakeFirebaseService();
    local = FakeLocalAccountData();
    auth = AuthViewModel(firebaseService: firebase, localData: local);
    await auth.signIn(_user.email, 'secret123');
  });

  test('signs the user out and wipes this phone once deleted', () async {
    final error = await auth.deleteAccount('secret123');

    expect(error, isNull);
    expect(firebase.deletedWith, ['secret123']);
    expect(auth.isAuthenticated, isFalse);
    expect(local.wipes, 1);
    expect(local.wipedUids, ['uid-1']);
    expect(auth.isLoading, isFalse);
  });

  test('keeps the account and local data when the password is wrong', () async {
    firebase.deleteError = FirebaseAuthException(code: 'wrong-password');

    final error = await auth.deleteAccount('nope');

    expect(error, 'Incorrect password.');
    expect(auth.isAuthenticated, isTrue);
    expect(local.wipes, 0);
  });

  test(
    'reports a connection problem when cloud data cannot be removed',
    () async {
      firebase.deleteError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      final error = await auth.deleteAccount('secret123');

      expect(error, 'Could not save. Check your connection and try again.');
      expect(auth.isAuthenticated, isTrue);
      expect(local.wipes, 0);
    },
  );

  test('still succeeds when clearing this phone fails afterwards', () async {
    local.wipeError = Exception('disk full');

    final error = await auth.deleteAccount('secret123');

    expect(error, isNull);
    expect(auth.isAuthenticated, isFalse);
  });

  test('refuses when nobody is signed in', () async {
    final signedOut = AuthViewModel(
      firebaseService: firebase,
      localData: local,
    );

    final error = await signedOut.deleteAccount('secret123');

    expect(error, 'You are signed out. Sign in again.');
    expect(firebase.deletedWith, isEmpty);
  });
}
