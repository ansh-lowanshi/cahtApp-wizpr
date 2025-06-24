import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import 'home_screen.dart';

class AddDetailsScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String displayName;

  const AddDetailsScreen({
    Key? key,
    required this.uid,
    required this.email,
    required this.displayName,
  }) : super(key: key);

  @override
  State<AddDetailsScreen> createState() => _AddDetailsScreenState();
}

class _AddDetailsScreenState extends State<AddDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();

  bool _submitting = false;
  String? _usernameError;
  List<String> _suggestedUsernames = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.displayName);
    _usernameCtrl.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _onUsernameChanged() async {
    final base = _usernameCtrl.text.trim();
    if (base.isEmpty) {
      setState(() {
        _usernameError = null;
        _suggestedUsernames.clear();
      });
      return;
    }

    final taken = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: base)
        .limit(1)
        .get();

    if (taken.docs.isNotEmpty) {
      setState(() {
        _usernameError = 'Username "$base" is already taken';
        _suggestedUsernames.clear();
      });
      final suggestions = await _generateUsernameSuggestions(base, count: 2);
      if (!mounted) return;
      setState(() => _suggestedUsernames = suggestions);
    } else {
      setState(() {
        _usernameError = null;
        _suggestedUsernames.clear();
      });
    }
  }

  Future<List<String>> _generateUsernameSuggestions(String base,
      {int count = 2}) async {
    final out = <String>[];
    int suffix = 1;
    while (out.length < count && suffix < 1000) {
      final candidate = '$base$suffix';
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: candidate)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) out.add(candidate);
      suffix++;
    }
    return out;
  }

  Future<void> _pickDob() async {
    final today = DateTime.now();
    final initial = today.subtract(const Duration(days: 365 * 20));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (picked != null) {
      _dobCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  String _generateFriendCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<String> _generateUniqueFriendCode() async {
    String code = _generateFriendCode(6);
    var snap = await FirebaseFirestore.instance
        .collection('users')
        .where('friendCode', isEqualTo: code)
        .limit(1)
        .get();

    while (snap.docs.isNotEmpty) {
      code = _generateFriendCode(6);
      snap = await FirebaseFirestore.instance
          .collection('users')
          .where('friendCode', isEqualTo: code)
          .limit(1)
          .get();
    }
    return code;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final friendCode = await _generateUniqueFriendCode();
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'uid': widget.uid,
        'email': widget.email,
        'name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'dob': _dobCtrl.text,
        'friendCode': friendCode,
        'friends': <String>[],
        'pendingRequests': <String>[],
        'sentRequests': <String>[],
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 320.w,
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15.r,
                        spreadRadius: 5.r,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Complete Your Profile',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepCherry,
                          ),
                        ),
                        SizedBox(height: 16.h),

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (s) => s!.trim().isEmpty
                                    ? 'Name cannot be empty'
                                    : null,
                              ),
                              SizedBox(height: 16.h),

                              TextFormField(
                                controller: _usernameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: const Icon(Icons.alternate_email),
                                  errorText: _usernameError,
                                ),
                                validator: (s) {
                                  final t = s!.trim();
                                  if (t.length < 4) return 'At least 4 characters';
                                  return null;
                                },
                              ),
                              SizedBox(height: 12.h),

                              if (_suggestedUsernames.isNotEmpty)
                                Row(
                                  children: _suggestedUsernames.map((s) {
                                    return GestureDetector(
                                      onTap: () => _usernameCtrl.text = s,
                                      child: Container(
                                        margin: EdgeInsets.only(right: 12.w),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12.w,
                                          vertical: 8.h,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10.r),
                                          color: Colors.black12,
                                        ),
                                        child: Text(
                                          s,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),

                              SizedBox(height: 16.h),

                              TextFormField(
                                controller: _dobCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Date of Birth',
                                  prefixIcon: Icon(Icons.cake),
                                ),
                                onTap: _pickDob,
                                validator: (s) =>
                                    s!.isEmpty ? 'Please select your DOB' : null,
                              ),
                              SizedBox(height: 32.h),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.deepCherry,
                                    padding: EdgeInsets.symmetric(vertical: 16.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                  child: Text(
                                    _submitting ? 'Saving…' : 'Continue',
                                    style: TextStyle(fontSize: 16.sp),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
