import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';
import 'package:watchparty/services/room_session.dart';

class _Rooms implements RoomService {
  final left = <(String, String)>[];

  @override
  Future<void> removeParticipant(String roomId, String userId,
      {String? notificationDeviceId}) async {
    left.add((roomId, userId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the remembered room survives restart and is scoped to the user',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final rooms = _Rooms();
    final session = RoomSession(prefs, rooms, pushEnabled: false);
    await session.remember('alice', 'ABC234', 'tr');
    session.dispose();

    final reopened = RoomSession(await SharedPreferences.getInstance(), rooms,
        pushEnabled: false);
    const notification = RemoteMessage(data: {
      'type': 'room_chat',
      'roomId': 'ABC234',
      'recipientId': 'alice',
    });
    expect(reopened.savedRoom('alice'), 'ABC234');
    expect(reopened.savedRoom('bob'), isNull);
    expect(reopened.notificationRoom(notification, 'bob'), isNull);
    expect(reopened.notificationRoom(notification, 'alice'), 'ABC234');

    await reopened.leave('alice', 'ABC234');
    expect(reopened.savedRoom('alice'), isNull);
    expect(reopened.notificationRoom(notification, 'alice'), isNull);
    expect(rooms.left, [('ABC234', 'alice')]);
    reopened.dispose();
  });
}
