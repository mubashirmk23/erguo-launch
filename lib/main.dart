import 'package:erguo/screens/admin/admin_dashboard.dart';
import 'package:erguo/screens/auth/login_screen.dart';
import 'package:erguo/screens/auth/register_screen.dart';
import 'package:erguo/screens/client/client_timer_view_screen.dart';
import 'package:erguo/screens/client/service_request_screen.dart';
import 'package:erguo/screens/client/payment_screen.dart';
import 'package:erguo/screens/worker/worker_login_screen.dart';
import 'package:erguo/screens/worker/worker_registration.dart';
import 'package:erguo/screens/worker/worker_timer_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/intro_screen.dart';
import 'screens/client/home_screen.dart';
import 'screens/client/request_screen.dart';
import 'screens/client/user_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/theme_provider.dart'; // Import theme provider

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // ✅ Ensure Flutter bindings are initialized

  // 🔹 Initialize Supabase
  await Supabase.initialize(
    url: 'https://vuppstdzzzwouvvsooyb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ1cHBzdGR6enp3b3V2dnNvb3liIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkzNzQyNDMsImV4cCI6MjA1NDk1MDI0M30.uHM2cNuXUvY2qUsi9l752I3njP62K79RKO_SNVRPKEU',
  );

  // 🔹 Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider); // Listen to theme changes

    return MaterialApp(
      title: 'Erguo',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode, // Dynamic theme mode
      initialRoute: '/', // 🔹 Debugging: Start from WorkerTimerScreen

      routes: {
        '/': (context) => IntroScreen(),
        '/home': (context) => const HomeScreen(),
        '/requests': (context) => const RequestScreen(),
        '/user': (context) => const UserScreen(),
        '/admin-login': (context) => AdminLoginScreen(),
        '/login': (context) => const UserLoginScreen(),
        '/register': (context) => const UserRegisterScreen(),
        '/adminDashboard': (context) => const AdminDashboard(),
        '/workerLogin': (context) => const WorkerLoginScreen(),
        '/workerRegister': (context) => WorkerRegisterScreen(),
      },

      debugShowCheckedModeBanner: false,

      // 🔹 Handle dynamic routes
      onGenerateRoute: (settings) {
        if (settings.name == '/workerTimer') {
          return MaterialPageRoute(
            builder: (context) => WorkerTimerScreen(
                requestId:
                    'JyZeBp9JI6QXSGp5rZpw'), // ✅ Fix: Provide test requestId
          );
        }

        if (settings.name == '/serviceRequest') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null && args.containsKey('serviceName')) {
            return MaterialPageRoute(
              builder: (context) =>
                  ServiceRequestScreen(serviceName: args['serviceName']),
            );
          }
        }

        // 🔹 Default fallback (if route doesn't exist)
        return MaterialPageRoute(builder: (context) => const HomeScreen());
      },
    );
  }
}
