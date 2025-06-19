import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UserService {
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
}
