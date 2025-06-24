import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme/app_colors.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final String callId;
  final String callerId;
  final bool isVideo;

  const IncomingCallScreen({
    Key? key,
    required this.callId,
    required this.callerId,
    required this.isVideo,
  }) : super(key: key);

  Future<String> _fetchCallerName() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(callerId).get();
    return (doc.data()?['name'] as String?) ?? 'Unknown';
  }

  void _acceptCall(BuildContext context) async {
    // mark connected
    await FirebaseFirestore.instance
      .collection('calls').doc(callId)
      .update({'status': 'connected'});
    Navigator.pop(context); // close incoming
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          friendId: callerId,
          isCaller: false,
          isVideo: isVideo,
          callId: callId,
        ),
      ),
    );
  }

  void _rejectCall(BuildContext context) async {
    await FirebaseFirestore.instance
      .collection('calls').doc(callId)
      .update({'status': 'rejected'});
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _fetchCallerName(),
      builder: (context, snap) {
        final callerName = snap.data ?? '...';
        return Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 24.w),
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$callerName is calling…',
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.h),
                  Text(isVideo ? 'Video Call' : 'Voice Call'),
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton(
                        backgroundColor: AppColors.deepCherry,
                        heroTag: 'reject',
                        onPressed: () => _rejectCall(context),
                        child: const Icon(Icons.call_end),
                      ),
                      FloatingActionButton(
                        backgroundColor: Colors.green,
                        heroTag: 'accept',
                        onPressed: () => _acceptCall(context),
                        child: const Icon(Icons.call),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
