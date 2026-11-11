import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/services/real_media_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Sovereign Voice Recorder Widget with dynamic waveform, timer,
/// permission gate (timer does not increment before microphone is active),
/// pause-and-listen preview with blue playback button, and record resume button.
class WhatsAppVoiceRecorder extends StatefulWidget {
  final Function onSend;
  final VoidCallback onCancel;

  const WhatsAppVoiceRecorder({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<WhatsAppVoiceRecorder> createState() => _WhatsAppVoiceRecorderState();
}

class _WhatsAppVoiceRecorderState extends State<WhatsAppVoiceRecorder>
    with SingleTickerProviderStateMixin {
  int _seconds = 0;
  Timer? _recordTimer;
  bool _isPaused = false;
  bool _isPlayingPreview = false;
  int _playbackProgressSeconds = 0;
  Timer? _playbackTimer;
  String? _previewAudioUrl;

  late AnimationController _pulseController;
  final List<double> _waveformSamples = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Initial waveform samples
    for (int i = 0; i < 16; i++) {
      _waveformSamples.add(0.2 + _random.nextDouble() * 0.6);
    }

    // Timer strictly begins ONLY when microphone stream has been approved/opened
    RealMediaService.instance.startMicrophoneRecording().then((granted) {
      if (granted && mounted && !_isPaused) {
        _startRecordTimer();
      }
    });
  }

  void _startRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          _seconds++;
          _waveformSamples.add(0.25 + _random.nextDouble() * 0.75);
          if (_waveformSamples.length > 28) {
            _waveformSamples.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _playbackTimer?.cancel();
    _pulseController.dispose();
    RealMediaService.instance.stopMicrophoneRecording();
    RealMediaService.instance.stopAudio();
    super.dispose();
  }

  void _seekPlayback(double ratio) {
    if (!_isPaused) return;
    setState(() {
      _playbackProgressSeconds = (ratio * (_seconds > 0 ? _seconds : 1)).round().clamp(0, _seconds);
    });
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _durationFormatted {
    if (_isPaused && _isPlayingPreview) {
      return _formatTime(_playbackProgressSeconds);
    }
    return _formatTime(_seconds);
  }

  void _pauseRecording() async {
    _recordTimer?.cancel();
    final url = await RealMediaService.instance.stopMicrophoneRecording();
    if (!mounted) return;
    setState(() {
      _isPaused = true;
      _previewAudioUrl = url;
      _isPlayingPreview = false;
      _playbackProgressSeconds = 0;
    });
  }

  void _resumeRecording() async {
    _playbackTimer?.cancel();
    RealMediaService.instance.stopAudio();
    await RealMediaService.instance.startMicrophoneRecording();
    if (!mounted) return;
    setState(() {
      _isPaused = false;
      _isPlayingPreview = false;
      _playbackProgressSeconds = 0;
    });
    _startRecordTimer();
  }

  void _togglePlaybackPreview() {
    if (_isPlayingPreview) {
      _playbackTimer?.cancel();
      RealMediaService.instance.stopAudio();
      setState(() => _isPlayingPreview = false);
    } else {
      RealMediaService.instance.playAudio(_previewAudioUrl);
      setState(() {
        _isPlayingPreview = true;
        if (_playbackProgressSeconds >= _seconds) {
          _playbackProgressSeconds = 0;
        }
      });

      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _playbackProgressSeconds++;
          if (_playbackProgressSeconds >= _seconds) {
            _isPlayingPreview = false;
            _playbackProgressSeconds = 0;
            RealMediaService.instance.stopAudio();
            timer.cancel();
          }
        });
      });
    }
  }

  void _finishAndSend() async {
    _recordTimer?.cancel();
    _playbackTimer?.cancel();
    RealMediaService.instance.stopAudio();
    String? audioUrl = _previewAudioUrl;
    if (!_isPaused) {
      audioUrl = await RealMediaService.instance.stopMicrophoneRecording();
    }
    final dur = _formatTime(_seconds > 0 ? _seconds : 1);
    final wave = List<double>.from(_waveformSamples.isNotEmpty
        ? _waveformSamples
        : [0.3, 0.7, 0.5, 0.9, 0.4, 0.8, 0.6]);
    try {
      (widget.onSend as dynamic)(dur, wave, audioUrl);
    } catch (_) {
      (widget.onSend as dynamic)(dur, wave);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel / Delete trash button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 22),
            onPressed: widget.onCancel,
            tooltip: 'Supprimer l\'enregistrement',
          ),

          // Red recording indicator or Playback indicator
          if (!_isPaused)
            FadeTransition(
              opacity: _pulseController,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF0043B8),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 8),

          // Duration Timer (e.g. 00:07)
          Text(
            _durationFormatted,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),

          // Sound Waveform Bars with interactive draggable scrubber when paused
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _isPaused
                      ? (d) => _seekPlayback(d.localPosition.dx / constraints.maxWidth)
                      : null,
                  onHorizontalDragUpdate: _isPaused
                      ? (d) => _seekPlayback(d.localPosition.dx / constraints.maxWidth)
                      : null,
                  child: SizedBox(
                    height: 28,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(_waveformSamples.length, (index) {
                        final val = _waveformSamples[index];
                        final totalSamples = _waveformSamples.length;
                        final playedRatio = _seconds > 0 ? (_playbackProgressSeconds / _seconds) : 0.0;
                        final isPlayedBar = _isPaused && (index / totalSamples) <= playedRatio;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 3,
                          height: _isPaused ? 10 : (val * 24).clamp(4, 28),
                          decoration: BoxDecoration(
                            color: isPlayedBar
                                ? const Color(0xFF0043B8)
                                : (_isPaused
                                    ? const Color(0xFF94A3B8)
                                    : AppTheme.primary),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),

          // Controls when recording vs when paused
          if (!_isPaused) ...[
            // Pause button (met en pause l'enregistrement)
            IconButton(
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  color: Color(0xFF0F172A),
                  size: 20,
                ),
              ),
              onPressed: _pauseRecording,
              tooltip: 'Mettre en pause',
            ),
          ] else ...[
            // Playback Preview button
            GestureDetector(
              onTap: _togglePlaybackPreview,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0043B8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0043B8).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isPlayingPreview ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Resume recording button
            GestureDetector(
              onTap: _resumeRecording,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),

          // Send voice button
          GestureDetector(
            onTap: _finishAndSend,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0043B8), Color(0xFF245BDB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
