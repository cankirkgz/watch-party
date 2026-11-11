import 'package:firebase_auth/firebase_auth.dart';

/// Geriye dönük çağrılar için Firebase Auth kimliğini döndürür.
class UserPrefsService {
  static Future<String> getOrCreateUserId() async {
    final auth = FirebaseAuth.instance;
    final existing = auth.currentUser;
    if (existing != null) return existing.uid;
    final credential = await auth.signInAnonymously();
    return credential.user!.uid;
  }

  static Future<void> clearUserId() => FirebaseAuth.instance.signOut();
}
