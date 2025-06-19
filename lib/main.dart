import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:watchparty/core/router/app_router.dart';
import 'package:watchparty/feauters/home/view_model/home_view_model.dart';
import 'package:watchparty/feauters/home/services/home_room_creator_service.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';
import 'package:watchparty/services/firestore_service.dart';
import 'package:watchparty/services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase başlat
  await Firebase.initializeApp();

  // ✅ Benzersiz kullanıcı ID'si al
  final userId = await UserService.getOrCreateUserId();

  // ✅ Uygulamayı başlat
  runApp(WatchPartyApp(userId: userId));
}

class WatchPartyApp extends StatelessWidget {
  final String userId;
  const WatchPartyApp({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
      title: 'WatchParty',
      theme: ThemeData.dark(),
      builder: (context, child) {
        return BlocProvider(
          create: (_) => HomeViewModel(
            creatorService: HomeRoomCreatorService(
              firestoreService: FirestoreService(),
            ),
            roomService: RoomService(),
          ),
          child: child!,
        );
      },
    );
  }
}
