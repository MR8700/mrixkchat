import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/moment.dart';
import '../../../core/repositories/moment_repository.dart';
import '../../../core/repositories/profile_repository.dart';
import '../../../core/services/real_media_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_media_image.dart';
import '../../discussions/widgets/whatsapp_voice_recorder.dart';

class AddMomentDialog extends StatefulWidget {
  const AddMomentDialog({super.key});

  @override
  State<AddMomentDialog> createState() => _AddMomentDialogState();
}

class _AddMomentDialogState extends State<AddMomentDialog> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  MomentType _type = MomentType.image;

  // Media arranger parameters
  String? _selectedMediaUrl;
  String _selectedAspectRatio = '4:5'; // '1:1', '4:5', '9:16'
  double _zoomLevel = 1.0;
  double _videoTrimStart = 0.0;
  double _videoTrimEnd = 30.0;
  bool _isFilming = false;
  bool _isShootingCamera = false;

  // Voice status parameters
  bool _isRecordingVoice = false;
  int _voiceRecordSeconds = 0;
  Timer? _voiceRecordTimer;
  String? _recordedVoiceDuration;
  String? _recordedVoiceUrl;
  bool _isPlayingRecordedVoice = false;
  int _voicePlaybackSeconds = 0;
  Timer? _voicePlaybackTimer;

  @override
  void initState() {
    super.initState();
    _selectedMediaUrl = null;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _videoUrlController.dispose();
    _voiceRecordTimer?.cancel();
    _voicePlaybackTimer?.cancel();
    if (_isRecordingVoice) {
      RealMediaService.instance.stopMicrophoneRecording();
    }
    if (_isPlayingRecordedVoice) {
      RealMediaService.instance.stopAudio();
    }
    super.dispose();
  }

  void _chooseMedia({required bool isVideo}) async {
    setState(() {
      _type = isVideo ? MomentType.video : MomentType.image;
    });

    final picked = await RealMediaService.instance.pickMediaFile(isVideo: isVideo);
    if (picked != null && mounted) {
      setState(() {
        _selectedMediaUrl = picked;
        if (isVideo) _videoUrlController.text = picked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVideo
              ? 'Fichier vidéo chargé depuis votre appareil'
              : 'Image chargée avec succès'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openCameraLive({required bool isVideo}) async {
    setState(() {
      _type = isVideo ? MomentType.video : MomentType.image;
      _isShootingCamera = !isVideo;
      _isFilming = isVideo;
    });

    final photo = await RealMediaService.instance.captureCameraPhoto();
    if (mounted) {
      setState(() {
        _isShootingCamera = false;
        _isFilming = false;
        if (photo != null && photo.isNotEmpty) {
          _selectedMediaUrl = photo;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo prête au cadrage'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startMomentVoiceRecording() async {
    _voiceRecordSeconds = 0;
    setState(() {
      _isRecordingVoice = true;
      _recordedVoiceDuration = null;
      _recordedVoiceUrl = null;
      _isPlayingRecordedVoice = false;
    });

    await RealMediaService.instance.startMicrophoneRecording();

    _voiceRecordTimer?.cancel();
    _voiceRecordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRecordingVoice) {
        setState(() {
          _voiceRecordSeconds++;
        });
      }
    });
  }

  void _stopMomentVoiceRecording() async {
    _voiceRecordTimer?.cancel();
    final url = await RealMediaService.instance.stopMicrophoneRecording();
    final durStr = _formatTime(_voiceRecordSeconds > 0 ? _voiceRecordSeconds : 3);

    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _recordedVoiceDuration = durStr;
        _recordedVoiceUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message vocal enregistré ($durStr)'),
          backgroundColor: const Color(0xFF0043B8),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _togglePlayMomentRecordedVoice() {
    if (_isPlayingRecordedVoice) {
      _voicePlaybackTimer?.cancel();
      RealMediaService.instance.stopAudio();
      setState(() {
        _isPlayingRecordedVoice = false;
        _voicePlaybackSeconds = 0;
      });
    } else {
      RealMediaService.instance.playAudio(_recordedVoiceUrl);
      setState(() {
        _isPlayingRecordedVoice = true;
        _voicePlaybackSeconds = 0;
      });

      final totalSec = _voiceRecordSeconds > 0 ? _voiceRecordSeconds : 4;
      _voicePlaybackTimer?.cancel();
      _voicePlaybackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _voicePlaybackSeconds++;
          if (_voicePlaybackSeconds >= totalSec) {
            _isPlayingRecordedVoice = false;
            _voicePlaybackSeconds = 0;
            RealMediaService.instance.stopAudio();
            timer.cancel();
          }
        });
      });
    }
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _submit() {
    final text = _captionController.text.trim();
    if (text.isEmpty && _type == MomentType.quote) return;

    final videoUrl = _videoUrlController.text.trim();
    final effectiveMedia = (_type == MomentType.video && videoUrl.isNotEmpty)
        ? videoUrl
        : _selectedMediaUrl;

    if (_type == MomentType.image && (effectiveMedia == null || effectiveMedia.isEmpty) && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une photo ou saisir un texte'),
          backgroundColor: Color(0xFF0043B8),
        ),
      );
      return;
    }

    final myProfile = context.read<ProfileRepository>().getProfile();

    final moment = Moment(
      id: 'moment_${DateTime.now().millisecondsSinceEpoch}',
      authorId: myProfile.id,
      authorName: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi',
      authorAvatar: myProfile.avatarUrl,
      type: _type,
      timeAgo: 'À l\'instant • Statut protégé',
      caption: text.isNotEmpty
          ? text
          : (_type == MomentType.voice ? 'Statut vocal partagé' : 'Moment partagé'),
      mediaUrl: (_type == MomentType.image || _type == MomentType.video)
          ? effectiveMedia
          : (_type == MomentType.voice ? _recordedVoiceUrl : null),
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      voiceTitle: _type == MomentType.voice ? 'Note vocale spontanée' : null,
      voiceDuration: _type == MomentType.voice ? (_recordedVoiceDuration ?? '00:15') : null,
      heartCount: 0,
      userLiked: false,
    );

    context.read<MomentRepository>().createMoment(moment);
    Navigator.of(context).pop();
  }

  double get _currentAspectRatio {
    if (_selectedAspectRatio == '1:1') return 1.0;
    if (_selectedAspectRatio == '9:16') return 9.0 / 16.0;
    return 4.0 / 5.0;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome, color: Color(0xFF0043B8), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Créer un Moment / Statut',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Type Selector Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _typeTab(MomentType.image, 'Photo', Icons.photo_library_outlined),
                    const SizedBox(width: 8),
                    _typeTab(MomentType.video, 'Vidéo', Icons.videocam_outlined),
                    const SizedBox(width: 8),
                    _typeTab(MomentType.voice, 'Vocal + Texte', Icons.mic_none_outlined),
                    const SizedBox(width: 8),
                    _typeTab(MomentType.quote, 'Texte seul', Icons.format_quote_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Image & Video Source Actions
              if (_type == MomentType.image || _type == MomentType.video) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: Color(0xFF0043B8)),
                        ),
                        onPressed: () => _chooseMedia(isVideo: _type == MomentType.video),
                        icon: const Icon(Icons.folder_open_rounded, size: 18, color: Color(0xFF0043B8)),
                        label: Text(
                          _type == MomentType.video ? 'Choisir vidéo' : 'Choisir photo',
                          style: const TextStyle(color: Color(0xFF0043B8), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0043B8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _openCameraLive(isVideo: _type == MomentType.video),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(_type == MomentType.video ? 'Filmer direct' : 'Appareil photo'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Video URL Input (YouTube or direct stream)
                if (_type == MomentType.video) ...[
                  TextField(
                    controller: _videoUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Lien YouTube ou URL vidéo (ex: https://youtube.com/...)',
                      hintText: 'Collez un lien YouTube ou utilisez la vidéo sélectionnée',
                      prefixIcon: Icon(Icons.video_collection_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        setState(() => _selectedMediaUrl = val.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Media Arranger & Manual Framing Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cadrage & Format :',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                          ),
                          if (_type == MomentType.image)
                            Row(
                              children: ['1:1', '4:5', '9:16'].map((ratio) {
                                final isSel = _selectedAspectRatio == ratio;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedAspectRatio = ratio),
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSel ? const Color(0xFF0043B8) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSel ? const Color(0xFF0043B8) : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Text(
                                      ratio,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSel ? Colors.white : AppTheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Real Photo / Media Preview Container
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          color: const Color(0xFF0F172A),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_selectedMediaUrl == null || _selectedMediaUrl!.isEmpty)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.photo_library_outlined, size: 40, color: Colors.white38),
                                    SizedBox(height: 8),
                                    Text(
                                      'Sélectionnez une photo ou prenez-en une',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                )
                              else
                                Center(
                                  child: AspectRatio(
                                    aspectRatio: _currentAspectRatio,
                                    child: Transform.scale(
                                      scale: _zoomLevel,
                                      child: AppMediaImage(
                                        imageUrl: _selectedMediaUrl,
                                        fit: BoxFit.cover,
                                        borderRadius: BorderRadius.zero,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_isFilming || _isShootingCamera)
                                Container(
                                  color: Colors.black54,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(color: Colors.white),
                                        const SizedBox(height: 8),
                                        Text(
                                          _isFilming
                                              ? 'Enregistrement vidéo en direct...'
                                              : 'Prise de vue appareil photo...',
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Media loaded badge
                      if (_selectedMediaUrl != null && _selectedMediaUrl!.isNotEmpty) ...[
                        Row(
                          children: const [
                            Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Média prêt pour publication',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Zoom Slider
                      Row(
                        children: [
                          const Icon(Icons.zoom_in, size: 18, color: AppTheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          const Text('Zoom :', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                          Expanded(
                            child: Slider(
                              value: _zoomLevel,
                              min: 1.0,
                              max: 2.5,
                              activeColor: const Color(0xFF0043B8),
                              onChanged: (val) => setState(() => _zoomLevel = val),
                            ),
                          ),
                          Text('${(_zoomLevel * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),

                      // Video Trimmer Controls
                      if (_type == MomentType.video) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.content_cut, size: 16, color: AppTheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            const Text('Découpe (0-30s) :', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                            Expanded(
                              child: RangeSlider(
                                values: RangeValues(_videoTrimStart, _videoTrimEnd),
                                min: 0.0,
                                max: 30.0,
                                activeColor: const Color(0xFF0043B8),
                                onChanged: (vals) => setState(() {
                                  _videoTrimStart = vals.start;
                                  _videoTrimEnd = vals.end;
                                }),
                              ),
                            ),
                            Text('${_videoTrimStart.toInt()}s - ${_videoTrimEnd.toInt()}s', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Voice Status with Centered Big Mic Button
              if (_type == MomentType.voice) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // State 1: Idle - Big centered mic button
                      if (!_isRecordingVoice && _recordedVoiceDuration == null) ...[
                        GestureDetector(
                          onTap: _startMomentVoiceRecording,
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0043B8), Color(0xFF245BDB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0043B8).withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.mic, color: Colors.white, size: 42),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Appuyer pour enregistrer',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ]
                      // State 2: Actively recording
                      else if (_isRecordingVoice) ...[
                        GestureDetector(
                          onTap: _stopMomentVoiceRecording,
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444).withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 44),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _formatTime(_voiceRecordSeconds),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Enregistrement en cours... Appuyer pour terminer',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ]
                      // State 3: Recorded - Big play button to listen
                      else if (_recordedVoiceDuration != null) ...[
                        GestureDetector(
                          onTap: _togglePlayMomentRecordedVoice,
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0043B8), Color(0xFF245BDB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0043B8).withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPlayingRecordedVoice ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _isPlayingRecordedVoice
                              ? 'Lecture en cours (${_formatTime(_voicePlaybackSeconds)} / $_recordedVoiceDuration)'
                              : 'Écouter votre message ($_recordedVoiceDuration)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            _voicePlaybackTimer?.cancel();
                            RealMediaService.instance.stopAudio();
                            setState(() {
                              _isPlayingRecordedVoice = false;
                              _voicePlaybackSeconds = 0;
                              _recordedVoiceDuration = null;
                              _recordedVoiceUrl = null;
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
                          label: const Text(
                            'Recommencer l\'enregistrement',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Caption input with supporting text
              TextField(
                controller: _captionController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: _type == MomentType.voice
                      ? 'Ajouter une légende texte au vocal (à l\'appuie)...'
                      : 'Légende ou pensée pour vos contacts...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Location input
              if (_type != MomentType.quote)
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                    hintText: 'Lieu (ex: Paris, Côte Basque, En déplacement...)',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler', style: TextStyle(color: AppTheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0043B8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _submit,
                    child: const Text('Publier le Statut', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeTab(MomentType type, String label, IconData icon) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0043B8) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0043B8) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
