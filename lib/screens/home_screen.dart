import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatapp/screens/call_history_screen.dart';
import 'package:chatapp/screens/friend_request_screen.dart';
import 'package:chatapp/screens/incoming_call_screen.dart';
import 'package:chatapp/screens/profile_screen.dart';
import 'package:chatapp/screens/select_friend_screen.dart';
import 'package:chatapp/screens/chat_screen.dart';
import 'package:chatapp/screens/coming_soon_screen.dart';
import 'package:chatapp/services/encryption_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crystal_navigation_bar/crystal_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import 'login_screen.dart';

/// JumpingDots widget (same as before).
class JumpingDots extends StatefulWidget {
  final int dotCount;
  final Color color;
  final double jumpHeight;
  final Duration duration;
  final double dotSize;

  const JumpingDots({
    Key? key,
    this.dotCount = 5,
    required this.color,
    this.jumpHeight = 10.0,
    this.duration = const Duration(milliseconds: 8000),
    this.dotSize = 10.0,
  }) : super(key: key);

  @override
  State<JumpingDots> createState() => _JumpingDotsState();
}

class _JumpingDotsState extends State<JumpingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.jumpHeight + widget.dotSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          List<Widget> dots = [];
          for (int i = 0; i < widget.dotCount; i++) {
            double phase = i / widget.dotCount;
            double t = (_controller.value + phase) % 1.0;
            double offsetFactor = sin(2 * pi * t).abs();
            double offsetY = -offsetFactor * widget.jumpHeight;
            dots.add(
              Transform.translate(
                offset: Offset(0, offsetY),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: dots,
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userName;
  String? friendCode;
  String? currentUserId;
  int _selectedIndex = 0;
  StreamSubscription<QuerySnapshot>? _incomingSub;

  @override
  void initState() {
    super.initState();
    _loadUserDetails().then((_) {
      if (currentUserId != null) {
        _listenToIncomingCalls();
      }
    });
  }
  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }
  Future<void> _loadUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    currentUserId = user.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        userName = doc['name'] ?? '';
        friendCode = doc['friendCode'] ?? '';
      });
    }
  }
  void _listenToIncomingCalls() {
    _incomingSub = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                callId: change.doc.id,
                callerId: data['callerId'],
                isVideo: data['type'] == 'video',
              ),
            ),
          );
        }
      }
    });
  }

  Widget _buildFriendRequestIcon() {
    if (currentUserId == null) {
      return IconButton(
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        onPressed: _goToFriendRequests,
      );
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
            onPressed: _goToFriendRequests,
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>;
        final List<dynamic> pending = data['pendingRequests'] ?? [];
        final bool hasReq = pending.isNotEmpty;
        return Padding(
          padding: EdgeInsets.only(right: 8.w),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 48.w,
                height: 48.h,
                child: IconButton(
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                  onPressed: _goToFriendRequests,
                ),
              ),
              if (hasReq)
                Positioned(
                  top: 6.h,
                  right: 6.w,
                  child: Container(
                    width: 9.w,
                    height: 9.h,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  void _goToFriendRequests() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
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
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// CHAT TAB: a Column with header widgets + Expanded(chat list).
  Widget _buildChatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),
        Text(
          'Welcome,',
          style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w400, color: Colors.black87),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName ?? 'Loading...',
              style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: AppColors.deepCherry),
            ),
            SizedBox(height: 4.h),
            if (currentUserId != null)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(currentUserId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final username = data['username'] ?? '';
                  return Text(
                    'AKA - $username',
                    style: TextStyle(fontSize: 16.sp, color: Colors.black54),
                  );
                },
              ),
          ],
        ),
        SizedBox(height: 12.h),
        if (friendCode != null)
          Text(
            'Your Wizpr Code: $friendCode',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500, color: Colors.black54),
          ),
        SizedBox(height: 32.h),
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectFriendScreen()));
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.chat, color: AppColors.deepCherry, size: 20.r),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Pick a Friend to Wizpr',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          'Your Chats',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        SizedBox(height: 8.h),
        // Expanded ensures this area has bounded height
        Expanded(child: _buildChatList()),
      ],
    );
  }

  /// Chat list StreamBuilder: shows JumpingDots only in this area while loading.
  Widget _buildChatList() {
    if (currentUserId == null) {
      return const Center(child: Text('Loading user...'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading state: show jumping dots in this Expanded area
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: JumpingDots(
              dotCount: 5,
              color: AppColors.deepCherry,
              jumpHeight: 12.0,
              duration: const Duration(milliseconds: 8000),
              dotSize: 12.0,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return Center(
            child: JumpingDots(
              dotCount: 5,
              color: AppColors.deepCherry,
              jumpHeight: 12.0,
              duration: const Duration(milliseconds: 8000),
              dotSize: 12.0,
            ),
          );
        }
        final docs = snapshot.data!.docs;
        final chats = <String, Map<String, dynamic>>{};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final senderId = data['senderId'];
          final receiverId = data['receiverId'];
          if (senderId != currentUserId && receiverId != currentUserId) continue;
          final friendId = senderId == currentUserId ? receiverId : senderId;
          if (!chats.containsKey(friendId)) {
            chats[friendId] = {
              'lastMessage': EncryptionHelper.decryptMessage(data['text']),
              'timestamp': data['timestamp'],
            };
          }
        }
        if (chats.isEmpty) {
          return const Center(child: Text('No chats yet. Start one!'));
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 16.h),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final entry = chats.entries.elementAt(index);
            final friendId = entry.key;
            final lastMessage = entry.value['lastMessage'];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists) {
                  return const SizedBox();
                }
                final friendData = snap.data!;
                final friendUsername = friendData['username'] ?? '';
                final friendName = friendData['name'] ?? '';
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          friendId: friendId,
                          friendName: friendName,
                          friendUsername: friendUsername,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24.r,
                          backgroundColor: AppColors.deepCherry,
                          child: Icon(Icons.person, size: 25.sp, color: Colors.white),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friendUsername,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp, color: Colors.black87),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                lastMessage ?? '',
                                style: TextStyle(fontSize: 14.sp, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCallsTab() => const CallHistoryScreen();
  Widget _buildProfileTab() => const ProfileScreen();

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (_, __) {
        return Scaffold(
          extendBody: true,
          appBar: AppBar(
            elevation: 0,
            title: Text(
              'Wizpr',
              style: GoogleFonts.underdog(
                color: AppColors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.deepCherry, AppColors.raspberryRose],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            centerTitle: true,
            actions: [_buildFriendRequestIcon()],
          ),
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
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
                  child: () {
                    switch (_selectedIndex) {
                      case 0:
                        // Directly return the Column from _buildChatTab:
                        return _buildChatTab();
                      case 1:
                        return const ComingSoonScreen();
                      case 2:
                        return const ProfileScreen();
                      default:
                        return _buildChatTab();
                    }
                  }(),
                ),
              ),
            ],
          ),
          bottomNavigationBar: CrystalNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            backgroundColor: Colors.white.withOpacity(0.9),
            unselectedItemColor: Colors.grey,
            selectedItemColor: AppColors.deepCherry,
            height: 60.h,
            items:  [
              CrystalNavigationBarItem(icon: Icons.chat, unselectedIcon: Icons.chat_bubble_outline),
              CrystalNavigationBarItem(icon: Icons.call, unselectedIcon: Icons.call_outlined),
              CrystalNavigationBarItem(icon: Icons.person, unselectedIcon: Icons.person_outline),
            ],
          ),
        );
      },
    );
  }
}
