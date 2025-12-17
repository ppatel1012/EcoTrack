import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

// Global instance of your AuthService
final AuthService auth = AuthService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EcoTrackApp());
}

class UserSettings {
  final bool isDarkMode;
  final double textScale;

  const UserSettings({this.isDarkMode = false, this.textScale = 1.0});

  factory UserSettings.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>>? snap,
  ) {
    if (snap == null || !snap.exists) {
      return const UserSettings();
    }
    final data = snap.data() ?? {};
    final rawScale = data['textScale'] ?? 1.0;
    return UserSettings(
      isDarkMode: (data['isDarkMode'] ?? false) as bool,
      textScale: rawScale is num ? rawScale.toDouble() : 1.0,
    );
  }
}

class EcoTrackApp extends StatelessWidget {
  const EcoTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.userStream,
      builder: (context, authSnap) {
        // Still checking login state?
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        final user = authSnap.data;

        // NOT LOGGED IN → default (light) app that shows AuthScreen
        if (user == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'EcoTrack',
            theme: ThemeData(
              primarySwatch: Colors.green,
              brightness: Brightness.light,
            ),
            home: const AuthScreen(),
          );
        }

        // LOGGED IN → listen to user settings
        final settingsStream = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: settingsStream,
          builder: (context, settingsSnap) {
            final settings = UserSettings.fromSnapshot(settingsSnap.data);

            final theme = ThemeData(
              primarySwatch: Colors.green,
              brightness: settings.isDarkMode
                  ? Brightness.dark
                  : Brightness.light,
            );

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'EcoTrack',
              theme: theme,
              // Apply global text scaling
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(settings.textScale)),
                  child: child!,
                );
              },
              home: const HomeScreen(),
            );
          },
        );
      },
    );
  }
}
