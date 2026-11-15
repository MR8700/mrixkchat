import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../network/api_client.dart';

enum WebRtcCallPhase { idle, ringing, connecting, connected, ended, failed }

class IncomingRtcCall {
  final String callId;
  final String callerId;
  final bool isVideo;
  final String sdpOffer;

  const IncomingRtcCall({
    required this.callId,
    required this.callerId,
    required this.isVideo,
    required this.sdpOffer,
  });
}

/// Owns one peer connection and its signaling lifecycle for the active device.
class WebRtcCallService extends ChangeNotifier {
  WebRtcCallService._();
  static final WebRtcCallService instance = WebRtcCallService._();

  static const _turnUrl = String.fromEnvironment('TURN_URL');
  static const _turnUsername = String.fromEnvironment('TURN_USERNAME');
  static const _turnPassword = String.fromEnvironment('TURN_PASSWORD');

  final StreamController<IncomingRtcCall> _incomingController =
      StreamController<IncomingRtcCall>.broadcast();
  Stream<IncomingRtcCall> get incomingCalls => _incomingController.stream;
  final StreamController<String> _incomingEndedController =
      StreamController<String>.broadcast();
  Stream<String> get incomingEnded => _incomingEndedController.stream;

  StreamSubscription<Map<String, dynamic>>? _signalSubscription;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  final List<RTCIceCandidate> _pendingLocalCandidates = [];
  final Map<String, List<RTCIceCandidate>> _earlyRemoteCandidates = {};
  final Set<String> _pendingIncomingIds = {};
  String? callId;
  String? peerUserId;
  bool isVideo = false;
  bool isIncoming = false;
  bool _remoteDescriptionSet = false;
  bool _offerPublished = false;
  WebRtcCallPhase phase = WebRtcCallPhase.idle;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isActive =>
      phase == WebRtcCallPhase.ringing ||
      phase == WebRtcCallPhase.connecting ||
      phase == WebRtcCallPhase.connected;

  void bindSignals(Stream<Map<String, dynamic>> signals) {
    _signalSubscription?.cancel();
    _signalSubscription = signals.listen(_handleSignal);
  }

  void unbindSignals() {
    _signalSubscription?.cancel();
    _signalSubscription = null;
  }

  Map<String, dynamic> _configuration() {
    final servers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
    ];
    if (_turnUrl.isNotEmpty) {
      servers.add({
        'urls': _turnUrl,
        if (_turnUsername.isNotEmpty) 'username': _turnUsername,
        if (_turnPassword.isNotEmpty) 'credential': _turnPassword,
      });
    }
    return {'iceServers': servers, 'sdpSemantics': 'unified-plan'};
  }

  Future<void> startOutgoing({
    required String remoteUserId,
    required bool video,
  }) async {
    if (isActive) throw StateError('Un appel est déjà en cours.');
    if (remoteUserId.isEmpty) throw StateError('Destinataire introuvable.');
    await _reset();
    callId = 'call_${DateTime.now().microsecondsSinceEpoch}';
    peerUserId = remoteUserId;
    isVideo = video;
    isIncoming = false;
    phase = WebRtcCallPhase.ringing;
    notifyListeners();

    try {
      await _preparePeer();
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': video ? 1 : 0,
      });
      await _peerConnection!.setLocalDescription(offer);
      final sent = await ApiClient().sendCallOffer(
        callId: callId!,
        calleeId: remoteUserId,
        type: video ? 'VIDEO' : 'AUDIO',
        sdpOffer: offer.sdp ?? '',
      );
      if (!sent) throw StateError('Le serveur n’a pas remis l’appel.');
      _offerPublished = true;
      phase = WebRtcCallPhase.connecting;
      notifyListeners();
      await _flushLocalCandidates();
    } catch (_) {
      phase = WebRtcCallPhase.failed;
      await _closeMedia();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> acceptIncoming(IncomingRtcCall invitation) async {
    if (isActive) throw StateError('Un appel est déjà en cours.');
    await _reset();
    callId = invitation.callId;
    _pendingIncomingIds.remove(invitation.callId);
    _pendingRemoteCandidates.addAll(
      _earlyRemoteCandidates.remove(invitation.callId) ?? const [],
    );
    peerUserId = invitation.callerId;
    isVideo = invitation.isVideo;
    isIncoming = true;
    phase = WebRtcCallPhase.connecting;
    notifyListeners();

    try {
      await _preparePeer();
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(invitation.sdpOffer, 'offer'),
      );
      _remoteDescriptionSet = true;
      await _flushRemoteCandidates();
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': isVideo ? 1 : 0,
      });
      await _peerConnection!.setLocalDescription(answer);
      final sent = await ApiClient().sendCallAnswer(
        callId: callId!,
        sdpAnswer: answer.sdp ?? '',
      );
      if (!sent) throw StateError('La réponse à l’appel n’a pas été remise.');
      _offerPublished = true;
      await _flushLocalCandidates();
      notifyListeners();
    } catch (_) {
      phase = WebRtcCallPhase.failed;
      await _closeMedia();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> rejectIncoming(String id) async {
    _pendingIncomingIds.remove(id);
    _earlyRemoteCandidates.remove(id);
    await ApiClient().endCall(id);
    await _finish(remote: true);
  }

  Future<void> endCall() async {
    await _finish(remote: false);
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  Future<void> setCameraEnabled(bool enabled) async {
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  Future<void> setSpeakerphone(bool enabled) =>
      Helper.setSpeakerphoneOn(enabled);

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  Future<void> _preparePeer() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
              'frameRate': {'ideal': 30},
            }
          : false,
    });
    _localStream = stream;

    final connection = await createPeerConnection(_configuration());
    _peerConnection = connection;
    for (final track in stream.getTracks()) {
      await connection.addTrack(track, stream);
    }
    connection.onIceCandidate = (candidate) {
      if ((candidate.candidate ?? '').isEmpty) return;
      _pendingLocalCandidates.add(candidate);
      if (_offerPublished) unawaited(_flushLocalCandidates());
    };
    connection.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        notifyListeners();
      }
    };
    connection.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        phase = WebRtcCallPhase.connected;
        notifyListeners();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (phase != WebRtcCallPhase.ended) {
          phase = WebRtcCallPhase.failed;
          notifyListeners();
        }
      }
    };
  }

  Future<void> _handleSignal(Map<String, dynamic> event) async {
    final payload = event['payload'];
    if (payload is! Map) return;
    final data = Map<String, dynamic>.from(payload);
    switch (event['type']) {
      case 'CALL_OFFER':
        final id = (data['id'] ?? '').toString();
        final caller = (data['caller_id'] ?? '').toString();
        final offer = (data['sdp_offer'] ?? '').toString();
        if (id.isNotEmpty && caller.isNotEmpty && offer.isNotEmpty) {
          _pendingIncomingIds.add(id);
          _incomingController.add(IncomingRtcCall(
            callId: id,
            callerId: caller,
            isVideo: data['type'] == 'VIDEO',
            sdpOffer: offer,
          ));
        }
        break;
      case 'CALL_ANSWER':
        if (data['id'] != callId || _peerConnection == null) {
          final answeredCallId = (data['id'] ?? '').toString();
          if (_pendingIncomingIds.remove(answeredCallId)) {
            _earlyRemoteCandidates.remove(answeredCallId);
            _incomingEndedController.add(answeredCallId);
          }
          return;
        }
        final answer = (data['sdp_answer'] ?? '').toString();
        if (answer.isEmpty) return;
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(answer, 'answer'),
        );
        _remoteDescriptionSet = true;
        await _flushRemoteCandidates();
        break;
      case 'CALL_ANSWERED_ELSEWHERE':
        final answeredCallId = (data['id'] ?? '').toString();
        if (_pendingIncomingIds.remove(answeredCallId)) {
          _earlyRemoteCandidates.remove(answeredCallId);
          _incomingEndedController.add(answeredCallId);
        }
        break;
      case 'CALL_ICE':
        final incomingId = (data['call_id'] ?? '').toString();
        if (incomingId != callId) {
          if (_pendingIncomingIds.contains(incomingId)) {
            final early = _earlyRemoteCandidates.putIfAbsent(
              incomingId,
              () => <RTCIceCandidate>[],
            );
            if (early.length < 128) {
              final text = (data['candidate'] ?? '').toString();
              if (text.isNotEmpty) {
                early.add(RTCIceCandidate(
                  text,
                  data['sdp_mid'] as String?,
                  (data['sdp_m_line_index'] as num?)?.toInt(),
                ));
              }
            }
          }
          return;
        }
        final candidateText = (data['candidate'] ?? '').toString();
        if (candidateText.isEmpty) return;
        final index = (data['sdp_m_line_index'] as num?)?.toInt();
        final candidate = RTCIceCandidate(
          candidateText,
          data['sdp_mid'] as String?,
          index,
        );
        if (!_remoteDescriptionSet || _peerConnection == null) {
          _pendingRemoteCandidates.add(candidate);
        } else {
          await _peerConnection!.addCandidate(candidate);
        }
        break;
      case 'CALL_HANGUP':
        final endedCallId = (data['id'] ?? '').toString();
        if (endedCallId == callId) {
          await _finish(remote: true);
        } else if (_pendingIncomingIds.remove(endedCallId)) {
          _earlyRemoteCandidates.remove(endedCallId);
          _incomingEndedController.add(endedCallId);
        }
        break;
    }
  }

  Future<void> _flushLocalCandidates() async {
    final id = callId;
    if (id == null || !_offerPublished) return;
    final candidates = List<RTCIceCandidate>.from(_pendingLocalCandidates);
    _pendingLocalCandidates.clear();
    for (final candidate in candidates) {
      final sent = await ApiClient().sendCallIceCandidate(
        callId: id,
        candidate: candidate.candidate ?? '',
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
      );
      if (!sent) _pendingLocalCandidates.add(candidate);
    }
  }

  Future<void> _flushRemoteCandidates() async {
    final connection = _peerConnection;
    if (connection == null || !_remoteDescriptionSet) return;
    final candidates = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in candidates) {
      await connection.addCandidate(candidate);
    }
  }

  Future<void> _finish({required bool remote}) async {
    if (!remote && callId != null) await ApiClient().endCall(callId!);
    phase = WebRtcCallPhase.ended;
    await _closeMedia();
    notifyListeners();
  }

  Future<void> _reset() async {
    await _closeMedia();
    _pendingLocalCandidates.clear();
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet = false;
    _offerPublished = false;
    _remoteStream = null;
    callId = null;
    peerUserId = null;
    phase = WebRtcCallPhase.idle;
  }

  Future<void> _closeMedia() async {
    final connection = _peerConnection;
    _peerConnection = null;
    if (connection != null) {
      await connection.close();
      await connection.dispose();
    }
    final local = _localStream;
    _localStream = null;
    if (local != null) {
      for (final track in local.getTracks()) {
        await track.stop();
      }
      await local.dispose();
    }
    final remote = _remoteStream;
    _remoteStream = null;
    if (remote != null) await remote.dispose();
  }

  @override
  void dispose() {
    _signalSubscription?.cancel();
    _incomingController.close();
    _incomingEndedController.close();
    unawaited(_closeMedia());
    super.dispose();
  }
}
