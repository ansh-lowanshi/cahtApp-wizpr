// lib/services/signal_services.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  late String callDocId;

  /// Get user media (audio + optional video)
  Future<MediaStream> _getUserMedia(bool video) async {
    final mediaConstraints = {
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
            }
          : false,
    };
    return navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  /// Create a PeerConnection with Plan B (so addStream works)
  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ],
      // Force Plan B semantics so `addStream` is valid
      'sdpSemantics': 'plan-b',
    };
    final constraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    _pc = await createPeerConnection(configuration, constraints);

    // Send any ICE candidates to Firestore
    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null) {
        _firestore
            .collection('calls')
            .doc(callDocId)
            .collection('iceCandidates')
            .add(candidate.toMap());
      }
    };

    return _pc!;
  }

  /// Initiate a new call
  Future<void> makeCall(String callerId, String receiverId, bool video) async {
    // 1. Create call doc
    final doc = await _firestore.collection('calls').add({
      'callerId': callerId,
      'receiverId': receiverId,
      'type': video ? 'video' : 'voice',
      'status': 'ringing',
      'participants': [callerId, receiverId],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    callDocId = doc.id;

    // 2. Get local media & attach to PC
    _localStream = await _getUserMedia(video);
    final pc = await _createPeerConnection();
    pc.addStream(_localStream!);  // valid under Plan B

    // 3. Create offer
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await doc.update({'offer': offer.toMap()});

    // 4. Listen for answer
    doc.snapshots().listen((snap) async {
      final data = snap.data();
      if (data != null && data['answer'] != null) {
        final answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await pc.setRemoteDescription(answer);
      }
    });

    // 5. Listen for remote ICE candidates
    _firestore
        .collection('calls')
        .doc(callDocId)
        .collection('iceCandidates')
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final c = change.doc.data()!;
          pc.addCandidate(RTCIceCandidate(
            c['candidate'], c['sdpMid'], c['sdpMLineIndex'],
          ));
        }
      }
    });
  }

  /// Answer an existing call
  Future<MediaStream> answerCall(String callId, bool video) async {
    callDocId = callId;
    final doc = _firestore.collection('calls').doc(callId);
    final data = (await doc.get()).data()!;

    // 1. Get local media & attach
    _localStream = await _getUserMedia(video);
    final pc = await _createPeerConnection();
    pc.addStream(_localStream!);

    // 2. Set remote offer
    final offer = RTCSessionDescription(
      data['offer']['sdp'],
      data['offer']['type'],
    );
    await pc.setRemoteDescription(offer);

    // 3. Create answer
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await doc.update({'answer': answer.toMap(), 'status': 'connected'});

    // 4. Listen for ICE candidates
    _firestore
        .collection('calls')
        .doc(callId)
        .collection('iceCandidates')
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final c = change.doc.data()!;
          pc.addCandidate(RTCIceCandidate(
            c['candidate'], c['sdpMid'], c['sdpMLineIndex'],
          ));
        }
      }
    });

    return _localStream!;
  }

  MediaStream? get localStream => _localStream;
  RTCPeerConnection? get peerConnection => _pc;
}
