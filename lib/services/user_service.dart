import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watchparty/models/user_model.dart';

class UserService {
  Future<void> updateProfile(String id,
          {required String name,
          required String countryCode,
          required String languageCode,
          required String translationLanguage,
          required bool autoTranslate}) =>
      usersCollection.doc(id).set({
        'name': name.trim(),
        'countryCode': countryCode,
        'preferredLanguage': languageCode,
        'translationLanguage': translationLanguage,
        'autoTranslate': autoTranslate,
      }, SetOptions(merge: true));
  final CollectionReference<Map<String, dynamic>> usersCollection =
      FirebaseFirestore.instance.collection('users');

  Future<void> createOrUpdateUser(UserModel user) async {
    await usersCollection
        .doc(user.id)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUserById(String id) async {
    final doc = await usersCollection.doc(id).get();
    final data = doc.data();
    return data == null ? null : UserModel.fromMap(data);
  }

  Future<void> updateUserName(String id, String name) async {
    await usersCollection.doc(id).set({'name': name}, SetOptions(merge: true));
  }

  Future<void> updatePreferredLanguage(String id, String languageCode) async {
    await usersCollection.doc(id).set({
      'preferredLanguage': languageCode,
    }, SetOptions(merge: true));
  }
}
