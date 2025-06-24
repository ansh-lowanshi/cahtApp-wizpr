import 'package:chatapp/core/theme/app_colors.dart';
import 'package:chatapp/screens/select_friend_for_call_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return Center(
        child: Text(
          "Not logged in",
          style: TextStyle(fontSize: 16.sp),
        ),
      );
    }

    // Height of your bottom nav bar
    final bottomNavHeight = kBottomNavigationBarHeight.h;

    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.lightBlush, AppColors.vanillaCream],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              // Start a Call button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SelectFriendForCallScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_call, color: AppColors.deepCherry, size: 20.r),
                        SizedBox(width: 12.w),
                        Text(
                          'Start a Call',
                          style: TextStyle(fontSize: 16.sp),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Call History List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('calls')
                      .where('participants', arrayContains: currentUserId)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          "No past calls.",
                          style: TextStyle(fontSize: 16.sp),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      padding: EdgeInsets.only(bottom: bottomNavHeight + 16.h),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final isCaller = data['callerId'] == currentUserId;
                        final friendId = isCaller ? data['receiverId'] : data['callerId'];

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                          builder: (context, friendSnapshot) {
                            if (!friendSnapshot.hasData || !friendSnapshot.data!.exists) {
                              return const SizedBox();
                            }

                            final friendData = friendSnapshot.data!.data() as Map<String, dynamic>;
                            final friendName = friendData['name'] ?? 'Unknown';

                            final time = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
                            final type = data['type'] == 'video' ? 'Video' : 'Voice';

                            return Card(
                              elevation: 4,
                              margin: EdgeInsets.symmetric(vertical: 6.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                leading: Icon(
                                  data['type'] == 'video' ? Icons.videocam : Icons.call,
                                  color: AppColors.deepCherry,
                                  size: 24.r,
                                ),
                                title: Text(
                                  friendName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                subtitle: Text(
                                  "$type call • ${data['status']} • ${time.toLocal()}",
                                  style: TextStyle(fontSize: 12.sp),
                                ),
                                trailing: Icon(
                                  isCaller ? Icons.north_east : Icons.south_west,
                                  color: isCaller ? Colors.green : Colors.blue,
                                  size: 20.r,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
