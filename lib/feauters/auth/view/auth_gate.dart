import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchparty/feauters/auth/view/auth_page.dart';
import 'package:watchparty/services/auth_service.dart';
import 'package:watchparty/services/user_service.dart';
import 'package:watchparty/core/localization/app_locale_controller.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.builder});

  final Widget Function(BuildContext context, User user) builder;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return AnimatedBuilder(
        animation: auth,
        builder: (context, _) => StreamBuilder<User?>(
              stream: auth.authStateChanges,
              initialData: auth.currentUser,
              builder: (context, snapshot) {
                if (auth.isPreparing ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final user = snapshot.data;
                return user == null
                    ? const AuthPage()
                    : _AccountLanguage(
                        key: ValueKey(user.uid), user: user, builder: builder);
              },
            ));
  }
}

class _AccountLanguage extends StatefulWidget {
  const _AccountLanguage(
      {super.key, required this.user, required this.builder});
  final User user;
  final Widget Function(BuildContext, User) builder;
  @override
  State<_AccountLanguage> createState() => _AccountLanguageState();
}

class _AccountLanguageState extends State<_AccountLanguage> {
  late final Future<void> _restore;
  @override
  void initState() {
    super.initState();
    _restore = _restoreLanguage();
  }

  Future<void> _restoreLanguage() async {
    try {
      final profile = await UserService()
          .getUserById(widget.user.uid)
          .timeout(const Duration(seconds: 5));
      if (mounted && profile != null) {
        await context
            .read<AppLocaleController>()
            .setLanguage(profile.preferredLanguage, saveToAccount: false);
      }
    } catch (_) {
      // The saved device preference also works when the profile is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _restore,
        builder: (context, snapshot) => snapshot.connectionState ==
                ConnectionState.done
            ? widget.builder(context, widget.user)
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
}
