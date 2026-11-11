import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/call_log.dart';
import '../../../core/repositories/call_history_repository.dart';
import '../../../core/services/real_media_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_avatar.dart';

enum CallStatus { ringing, connected, unavailable, ended }

class CallDialog extends StatefulWidget {
  final String peerName;
  final String peerAvatar;
  final bool isVideo;
  final bool isPeerOnline;
  final Function(String callDuration, bool isVideo)? onCallEnded;

  const CallDialog({
    super.key,
    required this.peerName,
    required this.peerAvatar,
    this.isVideo = false,
    this.isPeerOnline = false,
    this.onCallEnded,
  });

  @override
  State<CallDialog> createState() => _CallDialogState();
}

class _CallDialogState extends State<CallDialog> with SingleTickerProviderStateMixin {
  int _seconds = 0;
  Timer? _callTimer;
  Timer? _connectTimer;
  CallStatus _status = CallStatus.ringing;

  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoOff = false;
  late AnimationController _pulseController;
  bool _hasLogged = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _startCallCycle();
  }

  void _startCallCycle() {
    _callTimer?.cancel();
    _connectTimer?.cancel();

    setState(() {
      _status = CallStatus.ringing;
      _seconds = 0;
      _hasLogged = false;
    });

    // Real acoustic ringtone & vibration while ringing
    RealMediaService.instance.startRingtone();
    RealMediaService.instance.vibrate();

    // 2 rings cycle (3000ms)
    _connectTimer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted || _status != CallStatus.ringing) return;
      RealMediaService.instance.stopRingtone();

      if (widget.isPeerOnline) {
        _connectCall();
      } else {
        _triggerUnavailable();
      }
    });
  }

  void _connectCall() {
    _connectTimer?.cancel();
    RealMediaService.instance.stopRingtone();

    setState(() {
      _status = CallStatus.connected;
      _seconds = 0;
    });

    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _status == CallStatus.connected) {
        setState(() => _seconds++);
      }
    });
  }

  @override
  void dispose() {
    _connectTimer?.cancel();
    _callTimer?.cancel();
    RealMediaService.instance.stopRingtone();
    _pulseController.dispose();
    super.dispose();
  }

  String get _durationString {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _logCallToHistory({required bool wasConnected}) {
    if (_hasLogged) return;
    _hasLogged = true;

    final now = DateTime.now();
    final timeStr =
        'Aujourd\'hui à ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dur = wasConnected ? _durationString : 'Sans réponse';

    try {
      context.read<CallHistoryRepository>().addCallLog(
            CallLog(
              id: 'call_${DateTime.now().millisecondsSinceEpoch}',
              peerName: widget.peerName,
              peerAvatar: widget.peerAvatar,
              isVideo: widget.isVideo,
              direction: wasConnected ? CallDirection.outgoing : CallDirection.missed,
              timestamp: timeStr,
              duration: dur,
            ),
          );
    } catch (_) {}

    if (widget.onCallEnded != null) {
      widget.onCallEnded!(dur, widget.isVideo);
    }
  }

  void _triggerUnavailable() {
    _connectTimer?.cancel();
    _callTimer?.cancel();
    RealMediaService.instance.stopRingtone();
    _pulseController.stop();

    setState(() {
      _status = CallStatus.unavailable;
    });

    _logCallToHistory(wasConnected: false);

    // Audible gentle notification
    RealMediaService.instance.speakAudibleMessage(
      'Le correspondant n\'est pas joignable pour le moment. Veuillez réessayer plus tard.',
    );
  }

  void _hangUpCall() {
    _connectTimer?.cancel();
    _callTimer?.cancel();
    RealMediaService.instance.stopRingtone();
    _pulseController.stop();

    final wasConnected = _status == CallStatus.connected;
    setState(() {
      _status = CallStatus.ended;
    });

    _logCallToHistory(wasConnected: wasConnected);

    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _closeDialog() {
    _connectTimer?.cancel();
    _callTimer?.cancel();
    RealMediaService.instance.stopRingtone();

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _status == CallStatus.connected;
    final isUnavailable = _status == CallStatus.unavailable;
    final isEnded = _status == CallStatus.ended;
    final isTerminated = isUnavailable || isEnded;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Container(
        width: 390,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF111C2C).withOpacity(0.2),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top status badge
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? AppTheme.secondaryLight
                              : (isTerminated
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFFEF3C7)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isConnected
                                ? const Color(0xFF20B8A5).withOpacity(0.4)
                                : (isTerminated
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFF59E0B)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? AppTheme.statusGreen
                                    : (isTerminated ? Colors.red : const Color(0xFFF59E0B)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isConnected
                                    ? (widget.isVideo
                                        ? 'Appel vidéo direct et protégé'
                                        : 'Appel audio direct et protégé')
                                    : (isUnavailable
                                        ? 'Correspondant indisponible'
                                        : (isEnded
                                            ? 'Appel terminé'
                                            : 'Sonnerie en cours...')),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isConnected
                                      ? AppTheme.secondary
                                      : (isTerminated
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFB45309)),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                      onPressed: _closeDialog,
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Video stream preview or Avatar with click-to-enlarge
                if (widget.isVideo && isConnected && !_isVideoOff) ...[
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDFE4ED)),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppAvatar(
                                name: widget.peerName,
                                avatarUrl: widget.peerAvatar,
                                radius: 36,
                                isClickable: true,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.peerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Flux haute définition direct et protégé',
                                style: TextStyle(color: Color(0xFF20B8A5), fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            width: 60,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                            ),
                            child: const Center(
                              child: Icon(Icons.videocam, color: Colors.white70, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!isConnected && !isTerminated)
                        FadeTransition(
                          opacity: _pulseController,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryContainer.withOpacity(0.4),
                                width: 8,
                              ),
                            ),
                          ),
                        ),
                      AppAvatar(
                        name: widget.peerName,
                        avatarUrl: widget.peerAvatar,
                        radius: 46,
                        isClickable: true,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                Text(
                  widget.peerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // Call duration / status description
                Text(
                  isConnected
                      ? _durationString
                      : (isUnavailable
                          ? 'Indisponible pour le moment'
                          : (isEnded
                              ? 'Durée totale : $_durationString'
                              : 'Sonnerie chez le correspondant...')),
                  style: TextStyle(
                    fontSize: isConnected ? 16 : 13,
                    fontFamily: isConnected ? 'monospace' : null,
                    fontWeight: FontWeight.bold,
                    color: isConnected
                        ? AppTheme.primary
                        : (isTerminated ? const Color(0xFFDC2626) : AppTheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 8),

                if (isUnavailable)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.volume_up_rounded, size: 16, color: Color(0xFFDC2626)),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Message vocal : "Correspondant indisponible."',
                            style: TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'Liaison directe confidentielle • Protection de la vie privée',
                    style: TextStyle(fontSize: 11, color: AppTheme.statusGreen, fontWeight: FontWeight.w500),
                  ),
                const SizedBox(height: 20),

                // Controls
                if (!isTerminated) ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildActionBtn(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        isActive: _isMuted,
                        label: 'Micro',
                        onTap: () => setState(() => _isMuted = !_isMuted),
                      ),
                      if (widget.isVideo)
                        _buildActionBtn(
                          icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                          isActive: _isVideoOff,
                          label: 'Caméra',
                          onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                        ),
                      _buildActionBtn(
                        icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
                        isActive: _isSpeaker,
                        label: 'HP',
                        onTap: () => setState(() => _isSpeaker = !_isSpeaker),
                      ),
                      _buildActionBtn(
                        icon: Icons.person_off_rounded,
                        isActive: false,
                        label: 'Simuler Occupé',
                        onTap: _triggerUnavailable,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Red hang up button
                  GestureDetector(
                    onTap: _hangUpCall,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                    ),
                  ),
                ] else ...[
                  // State when call ended or unavailable: Relancer l'appel button!
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0043B8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                        icon: Icon(widget.isVideo ? Icons.videocam : Icons.call, size: 18),
                        label: const Text(
                          'Relancer l\'appel',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _startCallCycle,
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _closeDialog,
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required bool isActive,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primary : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppTheme.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
