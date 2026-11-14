import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';

class RoomSession {
  RoomSession(this._prefs, this._rooms, {required this.pushEnabled});

  final SharedPreferences _prefs;
  final RoomService _rooms;
  final bool pushEnabled;
  final notificationChat = ValueNotifier<String?>(null);
  static final _roomCode = RegExp(r'^[A-Z0-9]{6}$');
  static const _deviceKey = 'room_notification_device';
  static const _permissionKey = 'room_notification_permission_requested';
  Future<void>? _registration;
  ({String userId, String roomId, String language, String token})? _registered;
  String? _token;
  bool _requestedRefresh = false;
  ({String userId, String roomId, String language})? _current;
  StreamSubscription<String>? _tokenChanges;

  String _key(String userId) => 'active_watch_room.$userId';

  String? savedRoom(String userId) {
    final code = _prefs.getString(_key(userId));
    return code != null && _roomCode.hasMatch(code) ? code : null;
  }

  void forget(String userId, String roomId) {
    if (savedRoom(userId) == roomId) {
      unawaited(_prefs.remove(_key(userId)));
    }
  }

  Future<void> remember(String userId, String roomId, String language) async {
    if (!_roomCode.hasMatch(roomId)) return;
    final previous = savedRoom(userId);
    if (previous != null && previous != roomId) {
      unawaited(leave(userId, previous).catchError((Object _) {}));
    }
    await _prefs.setString(_key(userId), roomId);
    if (savedRoom(userId) != roomId) return;
    _current = (userId: userId, roomId: roomId, language: language);
    refreshNotifications();
  }

  Future<void> leave(String userId, String roomId) async {
    if (_current?.userId == userId && _current?.roomId == roomId) {
      _current = null;
      _registered = null;
    }
    forget(userId, roomId);
    await _rooms.removeParticipant(roomId, userId,
        notificationDeviceId: _prefs.getString(_deviceKey));
  }

  // On sign-out this device stops receiving room alerts. Other devices on the
  // same account keep their own subscriptions.
  Future<void> signOut(String userId) async {
    final room = savedRoom(userId);
    if (_current?.userId == userId) _current = null;
    _registered = null;
    final deviceId = _prefs.getString(_deviceKey);
    await _prefs.remove(_key(userId));
    if (room != null && deviceId != null) {
      try {
        await _rooms
            .removeNotificationDevice(room, userId, deviceId)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        if (pushEnabled) {
          await FirebaseMessaging.instance
              .deleteToken()
              .timeout(const Duration(seconds: 3))
              .catchError((Object _) {});
          _token = null;
        }
      }
    }
  }

  String? notificationRoom(RemoteMessage? message, String? userId) {
    final id = message?.data['roomId'];
    return userId != null &&
            message?.data['type'] == 'room_chat' &&
            message?.data['recipientId'] == userId &&
            id is String &&
            id == savedRoom(userId)
        ? id
        : null;
  }

  void refreshNotifications() {
    if (!pushEnabled || _current == null) return;
    if (_registration != null) {
      _requestedRefresh = true;
      return;
    }
    _registration = _register().whenComplete(() {
      _registration = null;
      if (_requestedRefresh) {
        _requestedRefresh = false;
        refreshNotifications();
      }
    });
  }

  Future<void> _register() async {
    final current = _current;
    if (current == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      _tokenChanges ??= messaging.onTokenRefresh.listen((token) {
        _token = token;
        refreshNotifications();
      }, onError: (Object _) {});
      var permission = await messaging.getNotificationSettings();
      if (_current != current) return;
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional &&
          _prefs.getBool(_permissionKey) != true) {
        await _prefs.setBool(_permissionKey, true);
        if (_current != current) return;
        permission = await messaging.requestPermission(badge: false);
      }
      if (_current != current) return;
      final deviceId = _prefs.getString(_deviceKey);
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        if (deviceId != null) {
          _registered = null;
          await _rooms.removeNotificationDevice(
              current.roomId, current.userId, deviceId);
        }
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        for (var attempt = 0; attempt < 6; attempt++) {
          if (_current != current) return;
          if (await messaging.getAPNSToken() != null) break;
          if (attempt == 5) return;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      final token = _token ??= await messaging.getToken();
      if (token == null ||
          _current != current ||
          FirebaseAuth.instance.currentUser?.uid != current.userId) {
        return;
      }
      final id = deviceId ?? const Uuid().v4();
      if (deviceId == null) await _prefs.setString(_deviceKey, id);
      if (_current != current) return;
      final signature = (
        userId: current.userId,
        roomId: current.roomId,
        language: current.language,
        token: token,
      );
      if (_registered == signature) return;
      await _rooms
          .saveNotificationDevice(
              current.roomId, current.userId, id, token, current.language)
          .timeout(const Duration(seconds: 5));
      if (_current == current) _registered = signature;
    } on FirebaseException catch (error) {
      debugPrint('Chat notifications unavailable: ${error.code}');
    } catch (_) {
      // Background delivery is optional. The room and chat remain usable.
    }
  }

  void dispose() {
    _current = null;
    unawaited(_tokenChanges?.cancel());
    notificationChat.dispose();
  }
}
