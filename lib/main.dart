import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/initial_splash_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/wali_dashboard_screen.dart';
import 'providers/app_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppStateProvider(prefs),
        ),
      ],
      child: MyApp(prefs: prefs),
    ),
  );
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    // Check if user is already logged in
    final isLoggedIn = widget.prefs.getBool('is_logged_in') ?? false;
    final userRole = widget.prefs.getString('user_role') ?? 'user';

    Widget homeScreen;
    if (isLoggedIn) {
      // Route based on role
      if (userRole == 'wali') {
        homeScreen = const WaliDashboardScreen();
      } else {
        homeScreen = const AuthenticatedSplashScreen();
      }
    } else {
      homeScreen = const InitialSplashScreen();
    }

    return MaterialApp(
      title: 'OurEye',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: homeScreen,
      debugShowCheckedModeBanner: false,
    );
  }
}
