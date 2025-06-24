import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:encrypt/encrypt.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../services/encryption_helper.dart';
import 'home_screen.dart';

class ChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendUsername;

  const ChatScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.friendUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final encryptedText = EncryptionHelper.encryptMessage(text);
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(hours: 48));

    FirebaseFirestore.instance.collection('messages').add({
      'text': encryptedText,
      'senderId': currentUserId,
      'receiverId': widget.friendId,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
    });

    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(
            '${widget.friendUsername}',
            style: GoogleFonts.underdog(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 25.sp,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          centerTitle: true,
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
              child: Column(
                children: [
                  // Stylish header with friend's username
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 16.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          '“Encrypted like your secret playlist 🔒🎧 No one’s peeking. We wrap your Wizps in moonlight and seal them with silence 🌙🔐”',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // Messages list
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final allDocs = snapshot.data!.docs;
                        final messages = allDocs.where((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return (d['senderId'] == currentUserId &&
                                  d['receiverId'] == widget.friendId) ||
                              (d['senderId'] == widget.friendId &&
                                  d['receiverId'] == currentUserId);
                        }).toList();

                        if (messages.isEmpty) {
                          return const Center(
                            child: Text(
                              'No messages yet. Start chatting!',
                              style: TextStyle(fontSize: 16),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final data =
                                messages[index].data() as Map<String, dynamic>;
                            final isMe = data['senderId'] == currentUserId;
                            final decryptedText =
                                EncryptionHelper.decryptMessage(data['text']);

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 6.h,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.deepCherry.withOpacity(0.9)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  decryptedText,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Message input
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Type a message...',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.r),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: CircleAvatar(
                            backgroundColor: AppColors.deepCherry,
                            child: const Icon(Icons.send, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
