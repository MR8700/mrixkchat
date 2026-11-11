import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/real_media_service.dart';
import '../../../core/theme/app_theme.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String duration;
  final bool isCompact;
  final List<double>? waveform;
  final String? audioUrl;
  final bool isOutgoing;
  final ValueChanged<bool>? onPlayStateChanged;

  const AudioPlayerWidget({
    super.key,
    required this.duration,
    this.isCompact = false,
    this.waveform,
    this.audioUrl,
    this.isOutgoing = false,
    this.onPlayStateChanged,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentSeconds = 0;
  Timer? _timer;

  int get _totalSeconds {
    final parts = widget.duration.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      final total = m * 60 + s;
      if (total > 0) return total;
    }
    return 18;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_isPlaying) {
      widget.onPlayStateChanged?.call(false);
      RealMediaService.instance.stopAudio();
    }
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      widget.onPlayStateChanged?.call(_isPlaying);
      if (_isPlaying) {
        RealMediaService.instance.playAudio(widget.audioUrl);
        _timer?.cancel();
        _timer = Timer.periodic(
          Duration(milliseconds: (1000 / _playbackSpeed).round()),
          (timer) {
            if (!mounted) return;
            setState(() {
              _currentSeconds++;
              if (_currentSeconds >= _totalSeconds) {
                _isPlaying = false;
                _currentSeconds = 0;
                widget.onPlayStateChanged?.call(false);
                RealMediaService.instance.stopAudio();
                _timer?.cancel();
              }
            });
          },
        );
      } else {
        RealMediaService.instance.stopAudio();
        _timer?.cancel();
      }
    });
  }

  void _cycleSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
      if (_isPlaying) {
        _timer?.cancel();
        _timer = Timer.periodic(
          Duration(milliseconds: (1000 / _playbackSpeed).round()),
          (timer) {
            if (!mounted) return;
            setState(() {
              _currentSeconds++;
              if (_currentSeconds >= _totalSeconds) {
                _isPlaying = false;
                _currentSeconds = 0;
                RealMediaService.instance.stopAudio();
                _timer?.cancel();
              }
            });
          },
        );
      }
    });
  }

  void _seekByDx(double dx, double width) {
    if (width <= 0) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    setState(() {
      _currentSeconds = (ratio * _totalSeconds).round();
    });
  }

  String get _formattedTime {
    final m = _currentSeconds ~/ 60;
    final s = _currentSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isOutgoing
              ? Colors.white.withOpacity(0.15)
              : AppTheme.surfaceWarm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isOutgoing
                ? Colors.white24
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: widget.isOutgoing ? Colors.white : AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: widget.isOutgoing ? const Color(0xFF1D4ED8) : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTapDown: (details) => _seekByDx(details.localPosition.dx, 60),
              onHorizontalDragUpdate: (details) =>
                  _seekByDx(details.localPosition.dx, 60),
              child: SizedBox(
                width: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _bar(6, widget.isOutgoing ? Colors.white : AppTheme.primary),
                    _bar(12, widget.isOutgoing ? Colors.white : AppTheme.primary),
                    _bar(4, widget.isOutgoing ? Colors.white : AppTheme.primary),
                    _bar(10, widget.isOutgoing ? Colors.white : AppTheme.primary),
                    _bar(7, widget.isOutgoing ? Colors.white : AppTheme.primary),
                    _bar(12, widget.isOutgoing ? Colors.white38 : Colors.grey.shade300),
                    _bar(6, widget.isOutgoing ? Colors.white38 : Colors.grey.shade300),
                    _bar(8, widget.isOutgoing ? Colors.white38 : Colors.grey.shade300),
                    _bar(4, widget.isOutgoing ? Colors.white38 : Colors.grey.shade300),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isPlaying ? _formattedTime : widget.duration,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.isOutgoing ? Colors.white : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Standard Chat Bubble Voice Note Player
    final isOut = widget.isOutgoing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isOut ? Colors.white.withOpacity(0.12) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOut ? Colors.white.withOpacity(0.20) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sleek Play / Pause Button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isOut ? Colors.white : null,
                gradient: isOut
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF0043B8), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isOut ? Colors.black : const Color(0xFF0043B8))
                        .withOpacity(0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 24,
                color: isOut ? const Color(0xFF1D4ED8) : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform & Time Track
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform scrubber
                LayoutBuilder(
                  builder: (context, constraints) {
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _seekByDx(
                            details.localPosition.dx, constraints.maxWidth),
                        onHorizontalDragUpdate: (details) => _seekByDx(
                            details.localPosition.dx, constraints.maxWidth),
                        child: SizedBox(
                          height: 28,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _buildWaveformBars(isOut),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),

                // Timers & Voice info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying ? _formattedTime : '0:00',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOut ? Colors.white : const Color(0xFF0043B8),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          size: 11,
                          color: isOut ? Colors.white70 : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isOut ? 'Vocal chiffré' : 'Vocal vérifié',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: isOut ? Colors.white70 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.duration,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: isOut ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Speed Pill
          GestureDetector(
            onTap: _cycleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: isOut ? Colors.white.withOpacity(0.18) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isOut ? Colors.white24 : const Color(0xFFCBD5E1),
                ),
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: isOut ? Colors.white : AppTheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double height, Color color) {
    return Container(
      width: 3,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  List<Widget> _buildWaveformBars(bool isOut) {
    final bars = widget.waveform ?? [
      0.3, 0.5, 0.8, 0.4, 0.9, 0.6, 0.3, 0.7, 0.4, 0.6,
      0.8, 0.5, 0.3, 0.6, 0.4, 0.7, 0.2, 0.5, 0.7, 0.4,
      0.6, 0.8, 0.3, 0.7, 0.5, 0.9, 0.4, 0.6
    ];
    final progress = _totalSeconds > 0 ? (_currentSeconds / _totalSeconds) : 0.0;

    return bars.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      final isPlayed = (index / bars.length) <= progress;

      final Color barColor;
      if (isOut) {
        barColor = isPlayed ? Colors.white : Colors.white.withOpacity(0.38);
      } else {
        barColor = isPlayed ? const Color(0xFF0043B8) : const Color(0xFFCBD5E1);
      }

      return Container(
        width: 3.2,
        height: 6 + (value * 20),
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }).toList();
  }
}
