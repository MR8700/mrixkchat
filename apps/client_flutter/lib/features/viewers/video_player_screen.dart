import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/real_media_service.dart';
import '../../core/theme/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String? videoUrl;
  final String duration;
  final String? senderName;

  const VideoPlayerScreen({
    super.key,
    required this.title,
    String? videoUrl,
    String? videoUri,
    this.duration = '1:45',
    this.senderName,
  }) : videoUrl = videoUrl ?? videoUri;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isPlaying = false;
  double _currentPosition = 12.0; // seconds
  final double _totalDuration = 105.0; // 1:45 in seconds
  Timer? _playbackTimer;
  double _playbackSpeed = 1.0;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      RealMediaService.instance.playVideoInModal(widget.videoUrl!);
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_currentPosition < _totalDuration) {
            _currentPosition += 1 * _playbackSpeed;
          } else {
            _isPlaying = false;
            _currentPosition = 0;
            _playbackTimer?.cancel();
          }
        });
      });
    } else {
      _playbackTimer?.cancel();
    }
  }

  void _downloadVideo() async {
    if (_isDownloading || _isDownloaded) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.1;
    });

    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() {
        _downloadProgress = i / 10.0;
      });
    }

    setState(() {
      _isDownloading = false;
      _isDownloaded = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF065F46),
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vidéo HD déchiffrée et enregistrée dans : /MRixk/Media/Videos/',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatTime(double seconds) {
    final m = (seconds / 60).floor();
    final s = (seconds % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              'Par ${widget.senderName ?? 'Correspondant'} • Flux Haute Définition',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isDownloading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: _downloadProgress,
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isDownloaded ? Icons.file_download_done : Icons.file_download,
                    color: _isDownloaded ? AppTheme.statusGreen : Colors.white,
                  ),
            tooltip: _isDownloaded ? 'Déjà téléchargé' : 'Télécharger la vidéo',
            onPressed: _downloadVideo,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Partager',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Partage sécurisé re-chiffré')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Video simulation surface
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    radius: 0.9,
                  ),
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.movie_creation_outlined,
                      size: 90,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    if (!_isPlaying)
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.4),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 38),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Player Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black.withOpacity(0.85),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Timeline Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.primary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: AppTheme.primary,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: _currentPosition.clamp(0.0, _totalDuration),
                        min: 0.0,
                        max: _totalDuration,
                        onChanged: (val) {
                          setState(() {
                            _currentPosition = val;
                          });
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatTime(_currentPosition)} / ${_formatTime(_totalDuration)}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Speed toggle
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (_playbackSpeed == 1.0) {
                                    _playbackSpeed = 1.5;
                                  } else if (_playbackSpeed == 1.5) {
                                    _playbackSpeed = 2.0;
                                  } else {
                                    _playbackSpeed = 1.0;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_playbackSpeed}x',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.fullscreen, color: Colors.white, size: 24),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
