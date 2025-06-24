// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenUtil with your design dimensions
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Wizpr',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.romanticTheme.copyWith(
            textTheme: GoogleFonts.underdogTextTheme(
              AppTheme.romanticTheme.textTheme,
            ),
            // Also apply to primary text theme (AppBar, dialogs, etc.)
            primaryTextTheme: GoogleFonts.underdogTextTheme(
              AppTheme.romanticTheme.primaryTextTheme,
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
