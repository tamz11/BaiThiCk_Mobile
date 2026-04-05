import 'dart:developer'; // Thêm thư viện này để in log lỗi
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:baithick/firebase_options.dart';
import 'package:baithick/mainPage.dart';
import 'package:baithick/screens/doctorProfile.dart';
import 'package:baithick/screens/firebaseAuth.dart';
import 'package:baithick/screens/myAppointments.dart';
import 'package:baithick/screens/userProfile.dart';
import 'package:baithick/data/local_notification_service.dart';
import 'package:baithick/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Thêm try-catch để bắt lỗi Firebase không làm văng app
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    log("LỖI KHỞI TẠO FIREBASE: $e");
  }
  
  // 2. Thêm try-catch cho Notification
  try {
    await LocalNotificationService.instance.init();
  } catch (e) {
    log("LỖI KHỞI TẠO NOTIFICATION: $e");
  }
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Lưu ý: Nếu Firebase lỗi ở trên, dòng này có thể trả về null, nhưng app vẫn không crash
    final User? user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Doctor Appointment App',
      
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // THEME SÁNG
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF4B5AB5),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      
      // THEME TỐI
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4B5AB5),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
        ),
      ),

      initialRoute: user == null ? '/login' : '/',
      
      routes: {
        '/': (context) => MainPage(), 
        '/login': (context) => const FireBaseAuth(),
        '/home': (context) => MainPage(),
        '/profile': (context) => const UserProfile(),
        '/MyAppointments': (context) => const MyAppointments(),
        '/DoctorProfile': (context) => DoctorProfile(),
      },
    );
  }
}