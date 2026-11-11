import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/moment.dart';
import '../../../core/repositories/moment_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_media_image.dart';
import '../../discussions/widgets/audio_player_widget.dart';
import '../../viewers/video_player_screen.dart';

/// Fullscreen Sovereign Status / Story Viewer conforming to modern ephemeral story standards.
class MomentStoryViewerDialog extends StatefulWidget {
  final List<Moment> moments;
  final int initialIndex;
  final Moment? initialMoment;

  const MomentStoryViewerDialog({
    super.key,
    this.moments = const [],
    this.initialIndex = 0,
    this.initialMoment,
  });

  @override
  State<MomentStoryViewerDialog> createState() => _MomentStoryViewerDialogState();
}

class _MomentStoryViewerDialogState extends State<MomentStoryViewerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  final TextEditingController _replyController = TextEditingController();
  bool _isReplying = false;
  bool _isPaused = false;
  late List<Moment> _playlist;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.moments.isNotEmpty) {
      _playlist = List<Moment>.from(widget.moments);
      _currentIndex = widget.initialIndex.clamp(0, _playlist.length - 1);
    } else if (widget.initialMoment != null) {
      _playlist = [widget.initialMoment!];
      _currentIndex = 0;
    } else {
      _playlist = [];
      _currentIndex = 0;
    }

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_isReplying && !_isPaused) {
        _onStoryCompleted();
      }
    });

    if (_playlist.isNotEmpty) {
      _progressController.forward();
    }
  }

  void _onStoryCompleted() {
    if (!mounted || _isReplying || _isPaused) return;
    if (_currentIndex < _playlist.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (!mounted || _isReplying) return;
    if (_progressController.value > 0.2 || _currentIndex == 0) {
      _progressController.reset();
      if (!_isPaused) _progressController.forward();
    } else {
      setState(() {
        _currentIndex--;
      });
      _progressController.reset();
      if (!_isPaused) _progressController.forward();
    }
  }

  void _nextStory() {
    if (!mounted || _isReplying) return;
    if (_currentIndex < _playlist.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _progressController.reset();
      if (!_isPaused) _progressController.forward();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _pauseProgress() {
    if (_progressController.isAnimating) {
      _progressController.stop();
    }
  }

  void _resumeProgress() {
    if (!_progressController.isAnimating && !_isReplying && !_isPaused) {
      _progressController.forward();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _pauseProgress();
      } else {
        _resumeProgress();
      }
    });
  }

  Future<void> _openVideoPlayer(Moment moment) async {
    _pauseProgress();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          title: moment.caption.isNotEmpty ? moment.caption : 'Moment Vidéo',
          videoUrl: moment.mediaUrl,
          senderName: moment.authorName,
        ),
      ),
    );
    if (mounted && !_isPaused) {
      _resumeProgress();
    }
  }

  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, _) {
          return Row(
            children: List.generate(_playlist.length, (index) {
              double val;
              if (index < _currentIndex) {
                val = 1.0;
              } else if (index == _currentIndex) {
                val = _progressController.value;
              } else {
                val = 0.0;
              }
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < _playlist.length - 1 ? 4.0 : 0.0,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: val,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 3.5,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_playlist.isEmpty) {
      return const SizedBox.shrink();
    }

    // Watch repository for live reaction updates
    final repo = context.watch<MomentRepository>();
    final activeMoment = _playlist[_currentIndex];
    final moment = repo.getMomentById(activeMoment.id) ?? activeMoment;

    return GestureDetector(
      onLongPressStart: (_) => _pauseProgress(),
      onLongPressEnd: (_) => _resumeProgress(),
      onLongPressCancel: () => _resumeProgress(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Story Progress Bars (Segmented by status in playlist)
              _buildProgressBars(),

              // 2. Author Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, Color(0xFF245BDB), AppTheme.secondaryGlow],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: AppAvatar(
                        name: moment.authorName,
                        avatarUrl: moment.authorAvatar,
                        radius: 19,
                        isClickable: false,
                        showBadge: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  moment.authorName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (moment.authorBadge != null) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.all(1.5),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text(
                                moment.timeAgo,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 11.5,
                                ),
                              ),
                              if (moment.location != null && moment.location!.isNotEmpty) ...[
                                Text(
                                  ' • ${moment.location}',
                                  style: const TextStyle(
                                    color: AppTheme.secondaryGlow,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_isPaused) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withOpacity(0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause, size: 12, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              'En pause',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    IconButton(
                      icon: Icon(
                        _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: _togglePause,
                      tooltip: _isPaused ? 'Reprendre la lecture' : 'Mettre en pause',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 26),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
              ),

              // 3. Status Content (Image / Video / Voice / Text Quote) with Tap Navigation
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: _buildStatusContent(moment),
                    ),
                    // Navigation tap strips at left/right edges (54px) so central interactive elements are never blocked
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 54,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _previousStory,
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 54,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _nextStory,
                        child: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Caption / Pensée overlay if present
              if (moment.caption.isNotEmpty && moment.type != MomentType.quote)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Text(
                      moment.caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // 5. Bottom Interactive Reaction & Reply Bar
              _buildBottomReactionsBar(context, moment),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusContent(Moment moment) {
    switch (moment.type) {
      case MomentType.image:
        if (moment.mediaUrl != null && moment.mediaUrl!.isNotEmpty) {
          return GestureDetector(
            onTap: _togglePause,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AppMediaImage(
                imageUrl: moment.mediaUrl!,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          );
        }
        return _buildQuoteContent(moment);

      case MomentType.video:
        return GestureDetector(
          onTap: () => _openVideoPlayer(moment),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (moment.mediaUrl != null && moment.mediaUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AppMediaImage(
                      imageUrl: moment.mediaUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.6),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.ondemand_video_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Regarder la vidéo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      case MomentType.voice:
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.secondary.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondary.withOpacity(0.15),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: AppTheme.secondary, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                moment.voiceTitle ?? 'Statut Vocal Chiffré',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Durée : ${moment.voiceDuration ?? '0:30'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 24),
              AudioPlayerWidget(
                duration: moment.voiceDuration ?? '0:30',
                audioUrl: moment.mediaUrl,
                onPlayStateChanged: (playing) {
                  if (playing) {
                    _pauseProgress();
                  } else {
                    if (!_isPaused) {
                      _resumeProgress();
                    }
                  }
                },
              ),
            ],
          ),
        );

      case MomentType.quote:
        return GestureDetector(
          onTap: _togglePause,
          child: _buildQuoteContent(moment),
        );
    }
  }

  Widget _buildQuoteContent(Moment moment) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.3),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: 48,
            color: AppTheme.secondaryGlow.withOpacity(0.8),
          ),
          const SizedBox(height: 16),
          Text(
            moment.caption,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.45,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (moment.location != null && moment.location!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 14, color: AppTheme.secondaryGlow),
                const SizedBox(width: 4),
                Text(
                  moment.location!,
                  style: const TextStyle(
                    color: AppTheme.secondaryGlow,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomReactionsBar(BuildContext context, Moment moment) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reactions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildReactionPill(
                emoji: '❤️',
                count: moment.heartCount,
                isActive: moment.userReaction == 'heart',
                onTap: () {
                  context.read<MomentRepository>().toggleReaction(moment.id, 'heart');
                },
              ),
              const SizedBox(width: 12),
              _buildReactionPill(
                emoji: '🔥',
                count: moment.moodCount,
                isActive: moment.userReaction == 'mood',
                onTap: () {
                  context.read<MomentRepository>().toggleReaction(moment.id, 'mood');
                },
              ),
              const SizedBox(width: 12),
              _buildReactionPill(
                emoji: '🎉',
                count: moment.celebrationCount,
                isActive: moment.userReaction == 'celebration',
                onTap: () {
                  context.read<MomentRepository>().toggleReaction(moment.id, 'celebration');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick reply input
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5),
                          onTap: () {
                            _pauseProgress();
                            setState(() => _isReplying = true);
                          },
                          onSubmitted: (val) => _sendReply(context, moment),
                          decoration: InputDecoration(
                            hintText: 'Répondre à ${moment.authorName}...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: AppTheme.secondary, size: 20),
                        onPressed: () => _sendReply(context, moment),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactionPill({
    required String emoji,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primary : Colors.white.withOpacity(0.2),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white.withOpacity(0.9),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _sendReply(BuildContext context, Moment moment) {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    setState(() => _isReplying = false);
    _resumeProgress();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Réponse envoyée en direct à ${moment.authorName}'),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
