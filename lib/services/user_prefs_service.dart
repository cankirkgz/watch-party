import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:watchparty/models/user_model.dart';
import 'package:watchparty/services/user_service.dart';

class UserPrefsService {
  static const String _userIdKey = 'anonymous_uid';

  /// UID'yi getir, yoksa oluştur
  static Future<String> getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString(_userIdKey);

    if (uid == null) {
      uid = const Uuid().v4();
      await prefs.setString(_userIdKey, uid);
      print('Yeni UID oluşturuldu: $uid');
      // Firestore'a anonim kullanıcı ekle
      final user = UserModel(id: uid, name: null, createdAt: DateTime.now());
      await UserService().createUser(user);
    } else {
      print('Mevcut UID bulundu: $uid');
    }

    return uid;
  }

  /// UID'yi silmek istersen (opsiyonel)
  static Future<void> clearUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
  }
}
