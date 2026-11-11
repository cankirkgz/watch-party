import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:watchparty/core/localization/app_locale_controller.dart';
import 'package:watchparty/core/router/app_router.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/feauters/home/services/home_room_creator_service.dart';
import 'package:watchparty/feauters/home/view_model/home_view_model.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';
import 'package:watchparty/firebase_options.dart';
import 'package:watchparty/services/auth_service.dart';
import 'package:watchparty/services/firestore_service.dart';
import 'package:watchparty/services/media_service.dart';
import 'package:watchparty/services/message_service.dart';
import 'package:watchparty/services/translation_service.dart';
import 'package:watchparty/services/user_service.dart';
import 'package:watchparty/services/voice_room_service.dart';
import 'package:livekit_client/livekit_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiveKitClient.initialize(
      initialAudioSessionOptions: watchPartyAudioSession);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
    final host = const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
        defaultValue: '');
    final emulatorHost = host.isNotEmpty
        ? host
        : kIsWeb
            ? 'localhost'
            : '10.0.2.2';
    await FirebaseAuth.instance
        .useAuthEmulator(emulatorHost, 9099, automaticHostMapping: false);
    FirebaseFirestore.instance
        .useFirestoreEmulator(emulatorHost, 8080, automaticHostMapping: false);
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .useFunctionsEmulator(emulatorHost, 5001, automaticHostMapping: false);
    await FirebaseStorage.instance
        .useStorageEmulator(emulatorHost, 9199, automaticHostMapping: false);
  }
  final localeController =
      AppLocaleController(onLanguageChanged: (language) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await UserService().updatePreferredLanguage(user.uid, language);
    }
  });
  await localeController.initialize();
  runApp(WatchPartyApp(localeController: localeController));
}

class WatchPartyApp extends StatelessWidget {
  const WatchPartyApp({super.key, required this.localeController});

  final AppLocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final roomService = RoomService(firestoreService);
    final creatorService = HomeRoomCreatorService(
      firestoreService: firestoreService,
    );
    final router = AppRouter.createRouter();

    return ChangeNotifierProvider<AppLocaleController>.value(
      value: localeController,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: firestoreService),
          RepositoryProvider.value(value: roomService),
          RepositoryProvider.value(value: creatorService),
          ChangeNotifierProvider(create: (_) => AuthService()),
          RepositoryProvider(create: (_) => MessageService()),
          RepositoryProvider(create: (_) => MediaService()),
          RepositoryProvider(create: (_) => TranslationService()),
        ],
        child: BlocProvider(
          create: (_) => HomeViewModel(
            creatorService: creatorService,
            roomService: roomService,
          ),
          child: AnimatedBuilder(
            animation: localeController,
            builder: (context, _) => MaterialApp.router(
              routerConfig: router,
              debugShowCheckedModeBanner: false,
              title: 'WatchParty',
              locale: localeController.locale,
              supportedLocales: AppLocaleController.supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                CountryLocalizations.delegate,
              ],
              theme: PartyTheme.light,
            ),
          ),
        ),
      ),
    );
  }
}
