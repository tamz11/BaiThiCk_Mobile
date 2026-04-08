import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:baithick/screens/doctorProfile.dart';
import 'package:baithick/screens/firebaseAuth.dart';
import 'package:baithick/firebase_options.dart';
import 'package:baithick/mainPage.dart';
import 'package:baithick/screens/myAppointments.dart';
import 'package:baithick/screens/userProfile.dart';
import 'package:baithick/data/local_notification_service.dart';
import 'package:baithick/utils/app_theme_controller.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationService.instance.init();
  await AppThemeController.instance.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ThemeData _lightTheme() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4B5AB5),
      brightness: Brightness.light,
    );

    final scheme = baseScheme.copyWith(
      surface: Colors.white,
      surfaceContainer: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainerHighest: const Color(0xFFF5F6FA),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.instance.mode,
      builder: (context, themeMode, _) => MaterialApp(
        initialRoute: '/',
        routes: {
          // When navigating to the "/" route, build the FirstScreen widget.
          '/': (context) => user == null ? FireBaseAuth() : MainPage(),
          '/login': (context) => FireBaseAuth(),
          '/home': (context) => MainPage(),
          '/profile': (context) => UserProfile(),
          '/MyAppointments': (context) => MyAppointments(),
          '/DoctorProfile': (context) => DoctorProfile(),
        },
        theme: _lightTheme(),
        darkTheme: ThemeData(brightness: Brightness.dark),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        //home: FirebaseAuthDemo(),
      ),
    );
  }
}
