// lib/screens/splash_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added
import '../core/theme/app_colors.dart';
import '../widgets/gradient_background.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _fadeAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
    ]).animate(_ctrl);

    _ctrl.forward();

    _ctrl.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        final user = FirebaseAuth.instance.currentUser;
        final prefs = await SharedPreferences.getInstance();
        final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

        late Widget nextPage;
        if (user != null) {
          nextPage = const HomeScreen();
        } else if (!seenOnboarding) {
          nextPage = const OnboardingScreen();
        } else {
          nextPage = const LoginScreen();
        }

        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextPage,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ));
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, color: AppColors.deepCherry, size: 80.r),
            SizedBox(height: 20.h),
            Text(
              "Welcome",
              style: GoogleFonts.underdog(
                fontSize: 34.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.deepCherry,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
