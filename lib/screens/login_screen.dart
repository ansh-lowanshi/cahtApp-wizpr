// lib/screens/login_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/theme/app_colors.dart';
import 'home_screen.dart';
import 'add_details_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Firebase & Google
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  // Loading & error
  bool _loading = false;
  String? _error;

  // UI state
  bool _useEmail = false;
  bool _isRegisterMode = false;
  bool _showPassword = false;

  // Email/password controllers
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkIfUserAlreadySignedIn();
  }

  Future<void> _checkIfUserAlreadySignedIn() async {
    final user = _auth.currentUser;
    if (user != null && user.emailVerified) {
      setState(() => _loading = true);
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _goToHome();
        return;
      }
      await _auth.signOut();
      setState(() => _loading = false);
    }
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _afterAuth(User user) async {
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    if (snapshot.exists) {
      _goToHome();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AddDetailsScreen(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? '',
          ),
        ),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final auth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final result = await _auth.signInWithCredential(cred);
      await _afterAuth(result.user!);
    } catch (e) {
      setState(() {
        _error = 'Google sign-in failed: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Email & password cannot be empty.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      UserCredential cred;
      if (_isRegisterMode) {
        // Register new user
        cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );
        // Send verification link
        await cred.user!.sendEmailVerification();
        setState(() => _error =
            'Verification email sent to $email. Please go and verify before signing in.');
      } else {
        // Sign in existing
        cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
        final user = cred.user!;
        if (!user.emailVerified) {
          // Not verified yet
          await user.sendEmailVerification();
          setState(() => _error =
              'Email not verified. A new verification link has been sent to $email.');
          await _auth.signOut();
        } else {
          // Verified: proceed
          await _afterAuth(user);
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email to reset password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.sendPasswordResetEmail(email: email);
      setState(() => _error =
          'Password reset email sent to your email. Please check your inbox.');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Background gradient
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.lightBlush, AppColors.vanillaCream],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),

        // Card
        Center(
          child: Container(
            width: 320.w,
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: AppColors.vanillaCream,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: _useEmail ? _buildEmailContent() : _buildDefaultContent(),
          ),
        ),
      ]),
    );
  }

  Widget _buildDefaultContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.favorite, color: AppColors.deepCherry, size: 60.r),
        SizedBox(height: 16.h),
        Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.deepCherry,
          ),
        ),
        SizedBox(height: 32.h),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: AppColors.rose, fontSize: 14.sp),
          ),
          SizedBox(height: 16.h),
        ],
        ElevatedButton.icon(
          onPressed: _loading ? null : _signInWithGoogle,
          icon: Icon(Icons.login, size: 20.r),
          label: Text(
            _loading ? 'Signing in...' : 'Sign in with Google',
            style: GoogleFonts.underdog(fontSize: 16.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepCherry,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Text('or', style: TextStyle(color: AppColors.deepCherry)),
        SizedBox(height: 8.h),
        TextButton(
          onPressed: () {
            setState(() {
              _useEmail = true;
              _error = null;
            });
          },
          child: Text('Use Email & Password'),
        ),
      ],
    );
  }

  Widget _buildEmailContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _isRegisterMode ? 'Register' : 'Sign In',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.deepCherry,
          ),
        ),
        SizedBox(height: 16.h),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: AppColors.rose, fontSize: 14.sp),
          ),
          SizedBox(height: 16.h),
        ],
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            labelStyle: TextStyle(color: AppColors.deepCherry),
          ),
        ),
        SizedBox(height: 12.h),
        TextField(
          controller: _passCtrl,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(color: AppColors.deepCherry),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.deepCherry,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        // Forgot password only in Sign-In mode:
        if (!_isRegisterMode) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : _resetPassword,
              child: const Text('Forgot Password?'),
            ),
          ),
        ],
        SizedBox(height: 8.h),
        ElevatedButton(
          onPressed: _loading ? null : _handleEmailAuth,
          child: Text(
            _loading
                ? (_isRegisterMode ? 'Registering...' : 'Signing in...')
                : (_isRegisterMode ? 'Register' : 'Sign In'),
            style: GoogleFonts.underdog(fontSize: 16.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepCherry,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        TextButton(
          onPressed: () {
            setState(() {
              _isRegisterMode = !_isRegisterMode;
              _error = null;
            });
          },
          child: Text(_isRegisterMode
              ? 'Have an account? Sign In'
              : 'Need an account? Register'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _useEmail = false;
              _isRegisterMode = false;
              _error = null;
            });
          },
          child: const Text('Back to Google Sign-In'),
        ),
      ],
    );
  }
}
