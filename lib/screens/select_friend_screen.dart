import 'package:chatapp/screens/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← for responsiveness
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class SelectFriendScreen extends StatelessWidget {
  const SelectFriendScreen({super.key});

  // Helper to chunk list of UIDs
  List<List<String>> chunkList(List<String> list, int chunkSize) {
    List<List<String>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(
        i,
        i + chunkSize > list.length ? list.length : i + chunkSize,
      ));
    }
    return chunks;
  }

  // Fetch all friends in batches of 10 UIDs
  Future<List<QueryDocumentSnapshot>> fetchFriendsInChunks(
      List<String> friendIds) async {
    List<QueryDocumentSnapshot> allFriends = [];
    final chunks = chunkList(friendIds, 10);

    for (var chunk in chunks) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', whereIn: chunk)
          .get();
      allFriends.addAll(querySnapshot.docs);
    }

    return allFriends;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (_, __) => Scaffold(
        appBar: AppBar(
          title: Text(
            'Select a Friend to Wizpr',
            style: GoogleFonts.underdog(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp, // responsive
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
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
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
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final List<dynamic> friendIdsRaw = userData['friends'] ?? [];
                  final List<String> friendIds = friendIdsRaw
                      .map((id) => id.toString())
                      .toList();

                  if (friendIds.isEmpty) {
                    return Center(
                      child: Text(
                        "You have no friends added.",
                        style: TextStyle(fontSize: 16.sp),
                      ),
                    );
                  }

                  return FutureBuilder<List<QueryDocumentSnapshot>>(
                    future: fetchFriendsInChunks(friendIds),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final friends = snapshot.data!;

                      return ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          final friendId = friend['uid'];
                          final friendName = friend['name'];
                          final friendUsername = friend['username'];

                          return Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            margin: EdgeInsets.only(bottom: 12.h),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              title: Text(
                                friendName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16.sp,
                                ),
                              ),
                              subtitle: Text(
                                '@$friendUsername',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14.sp,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 18.r,
                              ),
                              onTap: () {
                                Navigator.pushReplacement(
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
    );
  }
}
