import 'package:erguo/qrcode.dart';
import 'package:erguo/screens/admin/admin_dashboard.dart';
import 'package:erguo/screens/admin/admin_login_screen.dart';
import 'package:erguo/screens/auth/login_screen.dart';
import 'package:erguo/screens/auth/register_screen.dart';
import 'package:erguo/screens/client/home_screen.dart';
import 'package:erguo/screens/client/request_screen.dart';
import 'package:erguo/screens/client/user_screen.dart';
import 'package:erguo/screens/worker/worker_login_screen.dart';
import 'package:erguo/screens/worker/worker_registration.dart';
import 'package:erguo/screens/worker/worker_timer_screen.dart';
import 'package:erguo/screens/client/service_request_screen.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/theme_provider.dart';
import 'package:uni_links/uni_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vuppstdzzzwouvvsooyb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...YOUR_KEY',
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    handleDeepLink();
  }

  void handleDeepLink() async {
    final initialUri = await getInitialUri();
    if (initialUri != null) {
      if (initialUri.scheme == 'erguo' && initialUri.host == 'register') {
        _navigatorKey.currentState?.pushNamed('/register');
      }
    }

    uriLinkStream.listen((Uri? uri) {
      if (uri != null && uri.scheme == 'erguo' && uri.host == 'register') {
        _navigatorKey.currentState?.pushNamed('/register');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Erguo',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      initialRoute: '/qr',
      routes: {
        '/qr': (context) => const QRCodeScreen(), 
        '/register': (context) => const UserRegisterScreen(),
        '/login': (context) => const UserLoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/requests': (context) => const RequestScreen(),
        '/user': (context) => const UserScreen(),
        '/admin-login': (context) => AdminLoginScreen(),
        '/adminDashboard': (context) => const AdminDashboard(),
        '/workerLogin': (context) => const WorkerLoginScreen(),
        '/workerRegister': (context) => WorkerRegisterScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/workerTimer') {
          return MaterialPageRoute(
            builder: (_) => WorkerTimerScreen(requestId: 'JyZeBp9JI6QXSGp5rZpw'),
          );
        }

        if (settings.name == '/serviceRequest') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null && args.containsKey('serviceName')) {
            return MaterialPageRoute(
              builder: (_) =>
                  ServiceRequestScreen(serviceName: args['serviceName']),
            );
          }
        }

        return MaterialPageRoute(builder: (_) => const HomeScreen());
      },
    );
  }
}
