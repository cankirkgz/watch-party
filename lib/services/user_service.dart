import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watchparty/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UserService {
  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');

  static const _userIdKey = 'userId';

  /// Localde userId varsa onu döner, yoksa oluşturup kaydeder
  static Future<String> getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final existingUserId = prefs.getString(_userIdKey);

    if (existingUserId != null) return existingUserId;

    final newUserId = const Uuid().v4();
    await prefs.setString(_userIdKey, newUserId);
    return newUserId;
  }

  Future<void> createUser(UserModel user) async {
    await usersCollection.doc(user.id).set(user.toMap());
  }

  Future<UserModel?> getUserById(String id) async {
    final doc = await usersCollection.doc(id).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> updateUserName(String id, String name) async {
    await usersCollection.doc(id).update({'name': name});
  }
}
