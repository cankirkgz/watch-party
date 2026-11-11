import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:watchparty/models/user_model.dart';
import 'package:watchparty/services/user_service.dart';

class AuthService extends ChangeNotifier {
  bool _preparing = false;
  bool get isPreparing => _preparing;
  AuthService({FirebaseAuth? auth, UserService? userService})
      : _auth = auth ?? FirebaseAuth.instance,
        _userService = userService ?? UserService();

  final FirebaseAuth _auth;
  final UserService _userService;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
    required String languageCode,
    String countryCode = '',
  }) async {
    _preparing = true;
    notifyListeners();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      await _saveProfile(
          credential.user!, name.trim(), languageCode, countryCode);
      return credential;
    } finally {
      _preparing = false;
      notifyListeners();
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInAsGuest({
    required String name,
    required String languageCode,
    String countryCode = '',
  }) async {
    _preparing = true;
    notifyListeners();
    try {
      final credential = await _auth.signInAnonymously();
      final safeName = name.trim().isEmpty ? 'Guest' : name.trim();
      await credential.user?.updateDisplayName(safeName);
      await _saveProfile(credential.user!, safeName, languageCode, countryCode);
      return credential;
    } finally {
      _preparing = false;
      notifyListeners();
    }
  }

  Future<void> _saveProfile(
      User user, String name, String languageCode, String countryCode) {
    return _userService.createOrUpdateUser(
      UserModel(
        id: user.uid,
        name: name,
        email: user.email,
        preferredLanguage: languageCode,
        translationLanguage: languageCode,
        countryCode: countryCode,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> signOut() => _auth.signOut();
}
