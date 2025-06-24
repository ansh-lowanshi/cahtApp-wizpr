import 'dart:async';

import 'package:chatapp/services/signal_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CallScreen extends StatefulWidget {
  final String friendId;
  final bool isCaller;
  final bool isVideo;
  final String? callId;

  const CallScreen({
    Key? key,
    required this.friendId,
    required this.isCaller,
    this.isVideo = true,
    this.callId,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final SignalingService _signaling = SignalingService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    _start();
  }

  Future<void> _start() async {
    // 1. Request permissions
    final micStatus = await Permission.microphone.request();
    final camStatus = await Permission.camera.request();
    if (micStatus != PermissionStatus.granted ||
        (widget.isVideo && camStatus != PermissionStatus.granted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera & microphone permissions are required.")),
      );
      Navigator.pop(context);
      return;
    }

    // 2. Determine caller vs answer
    final me = FirebaseAuth.instance.currentUser!.uid;
    if (widget.isCaller) {
      await _signaling.makeCall(me, widget.friendId, widget.isVideo);
    } else {
      if (widget.callId == null) {
        // This should only happen if you forgot to pass callId from IncomingCallScreen
        throw Exception("Error: missing callId when answering a call");
      }
      await _signaling.answerCall(widget.callId!, widget.isVideo);
    }

    // 3. Attach local stream to renderer (if available)
    final localStream = _signaling.localStream;
    if (localStream != null) {
      _localRenderer.srcObject = localStream;
    }

    // 4. Hook up remote stream
    final pc = _signaling.peerConnection;
    if (pc != null) {
      pc.onAddStream = (stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      };
    }

    // 5. Start call duration timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _signaling.peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_seconds % 60).toString().padLeft(2, '0');

    // Determine mic icon state
    final audioTracks = _signaling.localStream?.getAudioTracks() ?? [];
    final isMicEnabled = audioTracks.isNotEmpty && audioTracks[0].enabled;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote view or blank background
          Positioned.fill(
            child: widget.isVideo
                ? RTCVideoView(_remoteRenderer)
                : Container(color: Colors.black),
          ),

          // Local preview (video only)
          if (widget.isVideo)
            Positioned(
              top: 32.h, right: 16.w, width: 120.w, height: 160.h,
              child: RTCVideoView(_localRenderer, mirror: true),
            ),

          // Call controls (hangup + mute)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 32.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Hang up
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(Icons.call_end),
                  ),
                  // Mute / Unmute
                  FloatingActionButton(
                    backgroundColor: Colors.white24,
                    onPressed: () {
                      if (audioTracks.isNotEmpty) {
                        final track = audioTracks[0];
                        track.enabled = !track.enabled;
                        setState(() {});
                      }
                    },
                    child: Icon(
                      isMicEnabled ? Icons.mic : Icons.mic_off,
                      color: isMicEnabled ? Colors.white : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Call timer display
          Positioned(
            top: 40.h, left: 16.w,
            child: Text(
              '$minutes:$secs',
              style: TextStyle(color: Colors.white, fontSize: 16.sp),
            ),
          ),
        ],
      ),
    );
  }
}
