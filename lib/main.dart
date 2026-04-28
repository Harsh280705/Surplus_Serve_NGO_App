// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'constants/app_constants.dart';
import 'screens/auth/auth_gate.dart';
import 'services/debug_fcm.dart';

// Services
import 'services/auth_service.dart';
import 'services/notification_service.dart';

// Screens
import 'screens/profile/profile_setup_page.dart';
import 'screens/dashboard/dashboard_page.dart'; // 🔥 Use DashboardPage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  await debugGetAndPrintFcmToken();

  final authService = AuthService();
  try {
    await NotificationService().initialize(authService);
  } catch (e, st) {
    debugPrint('❌ NotificationService init error: $e\n$st');
  }

  runApp(const SurplusServeApp());
}

class SurplusServeApp extends StatelessWidget {
  const SurplusServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      routes: {
        // 🔥 Use actual dashboard route
        '/dashboard': (context) => const DashboardPage(),
        
        // Profile setup route
        '/profile_setup': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ProfileSetupPage(
            userId: args['userId'] as String,
            role: args['role'] as String?,
          );
        },
      },
      home: const AuthGate(),
    );
  }
}