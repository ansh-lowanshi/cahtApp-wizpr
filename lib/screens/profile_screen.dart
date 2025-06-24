import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme/app_colors.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Friend code copied!')));
  }

  Future<void> _openFeedbackForm() async {
    final uri = Uri.parse('https://forms.gle/6Gi5uyqC4g2NUGJA7');

    // Use external application (the system browser)
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open feedback form')),
      );
    }
  }

  Widget _buildFriendList(List<dynamic> friendUids) {
    if (friendUids.isEmpty) {
      return Text(
        'No friends yet.',
        style: TextStyle(
          fontSize: 16.sp,
          color: AppColors.black.withOpacity(0.6),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          friendUids.map<Widget>((uid) {
            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance.collection('users').doc(uid).get(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text('Loading...'),
                  );
                }
                if (!snap.hasData || !snap.data!.exists) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text('Unknown User'),
                  );
                }
                final u = snap.data!.data() as Map<String, dynamic>;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20.r,
                        backgroundColor: AppColors.deepCherry,
                        child: Icon(
                          Icons.person,
                          size: 20.sp,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u['name'] ?? 'No Name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '@${u['username'] ?? 'unknown'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _getUserData(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('User data not found')),
          );
        }

        final data = snap.data!.data()!;
        final name = data['name'] ?? 'N/A';
        final username = data['username'] ?? 'N/A';
        final dob = data['dob'] ?? 'N/A';
        final friendCode = data['friendCode'] ?? 'N/A';
        final friends = List<String>.from(data['friends'] ?? []);

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.lightBlush, AppColors.vanillaCream],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(5.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Card
                    Card(
                      color: Colors.white.withOpacity(0.9),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 16.h,
                          horizontal: 12.w,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 35.r,
                              backgroundColor: AppColors.deepCherry,
                              child: Icon(
                                Icons.person,
                                size: 35.sp,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.deepCherry,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    '@$username',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color: AppColors.raspberryRose,
                                    ),
                                  ),
                                  if (currentEmail.isNotEmpty) ...[
                                    SizedBox(height: 4.h),
                                    Text(
                                      currentEmail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: AppColors.deepCherry,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // DOB & Friend Code Cards
                    Row(
                      children: [
                        // DOB card
                        Expanded(
                          child: Card(
                            color: Colors.white.withOpacity(0.9),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DOB',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.raspberryRose,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    dob,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color: AppColors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 12.w),

                        // Friend Code card with tap-to-copy
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _copyToClipboard(friendCode),
                            child: Card(
                              color: Colors.white.withOpacity(0.9),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(12.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wizpr Code',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.raspberryRose,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text(
                                      friendCode,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    // Logout and Feedback Button
                    Container(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Feedback Button on the left
                          ElevatedButton.icon(
                            onPressed: _openFeedbackForm,
                            icon: Icon(Icons.bug_report, size: 18.sp),
                            label: Text(
                              'Feedback',
                              style: GoogleFonts.underdog(fontSize: 16.sp),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.deepCherry,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 10.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          ),

                          // Logout Button on the right
                          ElevatedButton.icon(
                            onPressed: _logout,
                            icon: Icon(Icons.logout, size: 18.sp),
                            label: Text(
                              'Logout',
                              style: GoogleFonts.underdog(fontSize: 16.sp),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.deepCherry,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 10.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Friends Section with Card
                    Text(
                      'Friends',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepCherry,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Card(
                      color: Colors.white.withOpacity(0.9),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: _buildFriendList(friends),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
