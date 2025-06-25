import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:watchparty/core/router/app_router.dart';
import 'package:watchparty/feauters/home/services/home_room_creator_service.dart';
import 'package:watchparty/feauters/home/view_model/home_view_model.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';
import 'package:watchparty/services/firestore_service.dart';
import 'package:watchparty/services/user_prefs_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase başlat
  await Firebase.initializeApp();

  // Benzersiz kullanıcı ID'si al
  final userId = await UserPrefsService.getOrCreateUserId();

  // Uygulamayı başlat
  runApp(WatchPartyApp(userId: userId));
}

class WatchPartyApp extends StatelessWidget {
  final String userId;
  const WatchPartyApp({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Servisleri oluştur
    final firestoreService = FirestoreService();
    final roomService = RoomService(firestoreService);
    final creatorService =
        HomeRoomCreatorService(firestoreService: firestoreService);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FirestoreService>.value(value: firestoreService),
        RepositoryProvider<RoomService>.value(value: roomService),
        RepositoryProvider<HomeRoomCreatorService>.value(value: creatorService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<HomeViewModel>(
            create: (_) => HomeViewModel(
              creatorService: creatorService,
              roomService: roomService,
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: AppRouter.createRouter(userId),
          debugShowCheckedModeBanner: false,
          title: 'WatchParty',
          theme: ThemeData.dark(),
        ),
      ),
    );
  }
}
