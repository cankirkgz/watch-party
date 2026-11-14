import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:watchparty/services/room_session.dart';
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
  runApp(WatchPartyApp(
      localeController: localeController,
      preferences: await SharedPreferences.getInstance()));
}

class WatchPartyApp extends StatefulWidget {
  const WatchPartyApp(
      {super.key, required this.localeController, required this.preferences});

  final AppLocaleController localeController;
  final SharedPreferences preferences;

  @override
  State<WatchPartyApp> createState() => _WatchPartyAppState();
}

class _WatchPartyAppState extends State<WatchPartyApp> {
  final _firestoreService = FirestoreService();
  late final _roomService = RoomService(_firestoreService);
  late final _creatorService =
      HomeRoomCreatorService(firestoreService: _firestoreService);
  late final RoomSession _roomSession;
  late final GoRouter _router;
  StreamSubscription<RemoteMessage>? _notificationTaps;

  @override
  void initState() {
    super.initState();
    const emulator = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    final pushEnabled = !emulator &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    _roomSession =
        RoomSession(widget.preferences, _roomService, pushEnabled: pushEnabled);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _router = AppRouter.createRouter(
        initialRoomId: userId == null ? null : _roomSession.savedRoom(userId));
    if (pushEnabled) {
      _notificationTaps =
          FirebaseMessaging.onMessageOpenedApp.listen(_openNotification);
      unawaited(_openInitialNotification());
    }
  }

  Future<void> _openInitialNotification() async {
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openNotification(initial);
    } catch (_) {}
  }

  void _openNotification(RemoteMessage message) {
    if (!mounted) return;
    final roomId = _roomSession.notificationRoom(
        message, FirebaseAuth.instance.currentUser?.uid);
    if (roomId != null) {
      final path = '/room/$roomId';
      if (_router.routeInformationProvider.value.uri.path != path) {
        _router.go(path);
      } else {
        _roomSession.notificationChat.value = roomId;
        _roomSession.notificationChat.value = null;
      }
    }
  }

  @override
  void dispose() {
    unawaited(_notificationTaps?.cancel());
    _roomSession.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeController = widget.localeController;

    return ChangeNotifierProvider<AppLocaleController>.value(
      value: localeController,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: _firestoreService),
          RepositoryProvider.value(value: _roomService),
          RepositoryProvider.value(value: _creatorService),
          RepositoryProvider.value(value: _roomSession),
          ChangeNotifierProvider(
              create: (_) => AuthService(onSignOut: _roomSession.signOut)),
          RepositoryProvider(create: (_) => MessageService()),
          RepositoryProvider(create: (_) => MediaService()),
          RepositoryProvider(create: (_) => TranslationService()),
        ],
        child: BlocProvider(
          create: (_) => HomeViewModel(
            creatorService: _creatorService,
            roomService: _roomService,
          ),
          child: AnimatedBuilder(
            animation: localeController,
            builder: (context, _) => MaterialApp.router(
              routerConfig: _router,
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
