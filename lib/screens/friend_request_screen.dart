import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← for responsiveness
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({Key? key}) : super(key: key);

  @override
  _FriendRequestsScreenState createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _currentUid = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _codeCtrl = TextEditingController();

  bool _sending = false;
  List<DocumentSnapshot> _sent = [];
  List<DocumentSnapshot> _received = [];

  @override
  void initState() {
    super.initState();
    _loadFriendRequests();
  }

  Future<void> _loadFriendRequests() async {
    final docSnap = await _firestore.collection('users').doc(_currentUid).get();
    final data = docSnap.data() as Map<String, dynamic>? ?? {};

    final sentIds = (data['sentRequests'] as List<dynamic>? ?? []).cast<String>();
    final receivedIds = (data['pendingRequests'] as List<dynamic>? ?? []).cast<String>();

    final sentDocs = sentIds.isEmpty
        ? <DocumentSnapshot>[]
        : (await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: sentIds)
                .get())
            .docs;
    final receivedDocs = receivedIds.isEmpty
        ? <DocumentSnapshot>[]
        : (await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: receivedIds)
                .get())
            .docs;

    if (mounted) {
      setState(() {
        _sent = sentDocs;
        _received = receivedDocs;
      });
    }
  }

  Future<void> _sendRequest() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      _showSnackBar('Enter a Wizpr code');
      return;
    }

    setState(() => _sending = true);
    try {
      final q = await _firestore
          .collection('users')
          .where('friendCode', isEqualTo: code)
          .limit(1)
          .get();
      if (q.docs.isEmpty) throw 'No user with that code';

      final receiverId = q.docs.first.id;
      if (receiverId == _currentUid) throw 'Cannot send request to yourself';

      final pending =
          List<String>.from(q.docs.first.data()['pendingRequests'] ?? []);
      if (pending.contains(_currentUid)) throw 'Request already sent';

      await _firestore.collection('users').doc(receiverId).update({
        'pendingRequests': FieldValue.arrayUnion([_currentUid]),
      });
      await _firestore.collection('users').doc(_currentUid).update({
        'sentRequests': FieldValue.arrayUnion([receiverId]),
      });

      HapticFeedback.mediumImpact();
      _showSnackBar('Friend request sent!');
      _codeCtrl.clear();
      _loadFriendRequests();
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _accept(String senderId) async {
    final confirmed = await _showConfirmDialog('Accept this friend request?');
    if (!confirmed) return;

    await _firestore.runTransaction((tx) async {
      final meRef = _firestore.collection('users').doc(_currentUid);
      final themRef = _firestore.collection('users').doc(senderId);

      tx.update(meRef, {
        'friends': FieldValue.arrayUnion([senderId]),
        'pendingRequests': FieldValue.arrayRemove([senderId]),
      });
      tx.update(themRef, {
        'friends': FieldValue.arrayUnion([_currentUid]),
      });
    });

    HapticFeedback.selectionClick();
    _showSnackBar('Friend added!');
    _loadFriendRequests();
  }

  Future<void> _reject(String senderId) async {
    final confirmed = await _showConfirmDialog('Reject this friend request?');
    if (!confirmed) return;

    await _firestore.collection('users').doc(_currentUid).update({
      'pendingRequests': FieldValue.arrayRemove([senderId]),
    });

    HapticFeedback.heavyImpact();
    _showSnackBar('Request rejected.');
    _loadFriendRequests();
  }

  Future<bool> _showConfirmDialog(String msg) async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirm'),
            content: Text(msg, style: TextStyle(fontSize: 16.sp)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Yes', style: TextStyle(fontSize: 14.sp)),
              ),
            ],
          ),
        )) ??
        false;
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: TextStyle(fontSize: 14.sp))),
    );
  }

  Widget _buildTile(DocumentSnapshot doc, {bool sent = false}) {
    final data = doc.data() as Map<String, dynamic>;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: CircleAvatar(
        radius: 20.r,
        backgroundColor: AppColors.deepCherry.withOpacity(0.2),
        child: Icon(Icons.person, color: AppColors.deepCherry, size: 20.r),
      ),
      title: Text(data['name'] ?? 'Unnamed', style: TextStyle(fontSize: 16.sp)),
      subtitle: Text('@${data['username'] ?? 'unknown'}', style: TextStyle(fontSize: 14.sp)),
      trailing: sent
          ? Chip(label: Text('Sent', style: TextStyle(fontSize: 12.sp)))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.check, color: Colors.green, size: 24.r),
                  onPressed: () => _accept(doc.id),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red, size: 24.r),
                  onPressed: () => _reject(doc.id),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        elevation: 5,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Friend Requests',
          style: GoogleFonts.underdog(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.deepCherry, AppColors.raspberryRose],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white, size: 24.r),
            onPressed: _loadFriendRequests,
          ),
        ],
      ),
      body: Stack(
        children: [
          // background gradient
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
            child: SingleChildScrollView(
              padding: EdgeInsets.all(26.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Send Friend Code ──
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48.h,
                              child: TextField(
                                controller: _codeCtrl,
                                keyboardType: TextInputType.visiblePassword,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: 'Enter Wizpr code',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide.none,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                                  prefixIcon: Icon(Icons.code, size: 20.r),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          SizedBox(
                            height: 48.h,
                            child: ElevatedButton(
                              onPressed: _sending ? null : _sendRequest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.deepCherry,
                                minimumSize: Size(80.w, 48.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: _sending
                                  ? SizedBox(
                                      width: 20.w,
                                      height: 20.h,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text('Send', style: GoogleFonts.underdog(fontSize: 16.sp)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // ── Sent Requests ──
                  Text(
                    'Sent Requests',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepCherry,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    child: _sent.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(12.w),
                            child: Text(
                              'No sent requests',
                              style: TextStyle(
                                color: AppColors.black.withOpacity(0.6),
                                fontSize: 14.sp,
                              ),
                            ),
                          )
                        : Column(
                            children: _sent.map((d) => _buildTile(d, sent: true)).toList(),
                          ),
                  ),

                  SizedBox(height: 24.h),

                  // ── Received Requests ──
                  Text(
                    'Received Requests',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepCherry,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    child: _received.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(12.w),
                            child: Text(
                              'No received requests',
                              style: TextStyle(
                                color: AppColors.black.withOpacity(0.6),
                                fontSize: 14.sp,
                              ),
                            ),
                          )
                        : Column(
                            children: _received.map(_buildTile).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
