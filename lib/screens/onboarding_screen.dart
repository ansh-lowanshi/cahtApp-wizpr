// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added
import '../core/theme/app_colors.dart';
import '../widgets/gradient_background.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeInAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onGetStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: FadeTransition(
        opacity: _fadeInAnimation,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_outlined,
                size: 120.r,
                color: AppColors.deepCherry,
              ),
              SizedBox(height: 40.h),
              Text(
                "Welcome to Wizpr",
                style: GoogleFonts.underdog(
                  fontSize: 30.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepCherry,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: Text(
                  "Connect with friends, share moments, and make memories through chat, voice, and video calls. Let's get started!",
                  style: GoogleFonts.underdog(
                    fontSize: 16.sp,
                    color: AppColors.rose,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 40.h),
              ElevatedButton(
                onPressed: _onGetStarted,
                style: ElevatedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  backgroundColor: AppColors.deepCherry,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 40.w,
                    vertical: 15.h,
                  ),
                ),
                child: Text(
                  "Get Started",
                  style: GoogleFonts.underdog(
                    fontSize: 16.sp,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
