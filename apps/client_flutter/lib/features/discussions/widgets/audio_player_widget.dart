import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/real_media_service.dart';
import '../../../core/theme/app_theme.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String duration;
  final bool isCompact;
  final List<double>? waveform;
  final String? audioUrl;

  const AudioPlayerWidget({
    super.key,
    required this.duration,
    this.isCompact = false,
    this.waveform,
    this.audioUrl,
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
    return 42;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_isPlaying) {
      RealMediaService.instance.stopAudio();
    }
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        RealMediaService.instance.playAudio(widget.audioUrl);
        _timer = Timer.periodic(Duration(milliseconds: (1000 / _playbackSpeed).round()), (timer) {
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
        });
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
        _timer = Timer.periodic(Duration(milliseconds: (1000 / _playbackSpeed).round()), (timer) {
          if (!mounted) return;
          setState(() {
            _currentSeconds++;
            if (_currentSeconds >= _totalSeconds) {
              _isPlaying = false;
              _currentSeconds = 0;
              _timer?.cancel();
            }
          });
        });
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
          color: AppTheme.surfaceWarm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Mini interactive scrubber
            GestureDetector(
              onTapDown: (details) => _seekByDx(details.localPosition.dx, 60),
              onHorizontalDragUpdate: (details) => _seekByDx(details.localPosition.dx, 60),
              child: SizedBox(
                width: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _bar(6, AppTheme.primary),
                    _bar(12, AppTheme.primary),
                    _bar(4, AppTheme.primary),
                    _bar(10, AppTheme.primary),
                    _bar(7, AppTheme.primary),
                    _bar(12, Colors.grey.shade300),
                    _bar(6, Colors.grey.shade300),
                    _bar(8, Colors.grey.shade300),
                    _bar(4, Colors.grey.shade300),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isPlaying ? _formattedTime : widget.duration,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Full audio bar in active chat with draggable scrubber
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          // Play button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.secondary, AppTheme.secondaryGlow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform & Draggable Scrubber Timeline
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final progressRatio = _totalSeconds > 0
                        ? (_currentSeconds / _totalSeconds).clamp(0.0, 1.0)
                        : 0.0;

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) =>
                            _seekByDx(details.localPosition.dx, constraints.maxWidth),
                        onHorizontalDragUpdate: (details) =>
                            _seekByDx(details.localPosition.dx, constraints.maxWidth),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            SizedBox(
                              height: 26,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: _buildWaveformBars(),
                              ),
                            ),
                            // Draggable scrubbing cursor needle
                            Positioned(
                              left: (constraints.maxWidth * progressRatio - 4)
                                  .clamp(0.0, constraints.maxWidth - 8),
                              child: Container(
                                width: 8,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0043B8),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0043B8).withOpacity(0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formattedTime,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const Text(
                      'Tirer pour naviguer',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      widget.duration,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Speed button
          GestureDetector(
            onTap: _cycleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
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

  List<Widget> _buildWaveformBars() {
    final bars = widget.waveform ?? [
      0.3, 0.5, 0.8, 0.4, 0.9, 0.6, 0.3, 0.7, 0.4, 0.6, 0.8, 0.5, 0.3, 0.6, 0.4, 0.7, 0.2, 0.5, 0.7, 0.4
    ];
    final progress = _totalSeconds > 0 ? (_currentSeconds / _totalSeconds) : 0.0;

    return bars.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      final isPlayed = (index / bars.length) <= progress;
      return Container(
        width: 3.5,
        height: 6 + (value * 18),
        decoration: BoxDecoration(
          color: isPlayed ? AppTheme.secondary : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }).toList();
  }
}
