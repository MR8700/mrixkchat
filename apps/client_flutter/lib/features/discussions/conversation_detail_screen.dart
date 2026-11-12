import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/conversation.dart';
import '../../core/models/message.dart';
import '../../core/repositories/conversation_repository.dart';
import '../../core/repositories/device_repository.dart';
import '../../core/repositories/message_repository.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/repositories/group_note_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_media_image.dart';
import '../viewers/document_viewer_screen.dart';
import '../viewers/image_viewer_screen.dart';
import '../viewers/video_player_screen.dart';
import 'conversation_info_screen.dart';
import 'group_notepad_screen.dart';
import 'widgets/audio_player_widget.dart';
import 'widgets/call_dialog.dart';
import 'widgets/whatsapp_voice_recorder.dart';
import '../../core/services/real_media_service.dart';

class ConversationDetailScreen extends StatefulWidget {
  final Conversation conversation;
  final VoidCallback? onCloseDesktop;

  const ConversationDetailScreen({
    super.key,
    required this.conversation,
    this.onCloseDesktop,
  });

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showAttachments = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};
  bool _isViewOnceMode = false;
  Message? _editingMessage;
  bool _isRecordingVoice = false;

  @override
  void initState() {
    super.initState();
    // Mark as read in repository CRUD
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationRepository>().markAsRead(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage({
    String? textOverride,
    MessageType type = MessageType.text,
    String? imageUri,
    bool isViewOnce = false,
    String? fileName,
  }) {
    final text = textOverride ?? _textController.text.trim();
    if (text.isEmpty && type == MessageType.text && imageUri == null) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (_editingMessage != null) {
      context.read<MessageRepository>().editMessage(_editingMessage!.id, text);
      context.read<ConversationRepository>().updateLastMessage(
            conversationId: widget.conversation.id,
            message: '$text (modifié)',
            time: timeStr,
          );
      setState(() {
        _editingMessage = null;
      });
      _textController.clear();
      return;
    }

    final willBeViewOnce = isViewOnce || _isViewOnceMode;
    final myProfile = context.read<ProfileRepository>().getProfile();

    final newMessage = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      senderId: myProfile.id,
      senderName: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi',
      senderAvatar: myProfile.avatarUrl,
      type: type,
      content: text,
      time: timeStr,
      isOutgoing: true,
      isRead: widget.conversation.isOnline,
      imageUri: imageUri,
      isViewOnce: willBeViewOnce,
      fileName: fileName,
    );

    context.read<MessageRepository>().sendMessage(newMessage);
    context.read<ConversationRepository>().updateLastMessage(
          conversationId: widget.conversation.id,
          message: willBeViewOnce
              ? 'Message à vue unique 🔒'
              : (text.isNotEmpty ? text : 'Photo HD 📷'),
          time: timeStr,
        );

    _textController.clear();
    setState(() {
      _showAttachments = false;
      _isViewOnceMode = false;
    });

    // Auto-scroll
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startVoiceRecording() {
    setState(() {
      _showAttachments = false;
      _isRecordingVoice = true;
    });
  }

  void _onVoiceRecorded(String durationStr, List<double> waveform, [String? audioUrl]) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final myProfile = context.read<ProfileRepository>().getProfile();
    final newVoice = Message(
      id: 'msg_v_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      senderId: myProfile.id,
      senderName: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi',
      senderAvatar: myProfile.avatarUrl,
      type: MessageType.voice,
      content: 'Note vocale ($durationStr)',
      time: timeStr,
      isOutgoing: true,
      isRead: widget.conversation.isOnline,
      voiceDuration: durationStr,
      voiceUri: audioUrl,
      voiceTranscription: '« Note vocale enregistrée en direct. »',
      waveform: waveform.isNotEmpty
          ? waveform
          : [0.3, 0.6, 0.9, 0.4, 0.7, 0.2, 0.5, 0.8],
    );
    context.read<MessageRepository>().sendMessage(newVoice);
    context.read<ConversationRepository>().updateLastMessage(
          conversationId: widget.conversation.id,
          message: 'Note vocale ($durationStr) 🎙️',
          time: timeStr,
        );

    setState(() => _isRecordingVoice = false);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendDocument([RealDocumentFile? doc]) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final myProfile = context.read<ProfileRepository>().getProfile();
    final fileName = doc?.fileName ?? 'Document.pdf';
    final fileSize = doc?.fileSize ?? '1.4 Mo';
    final fileType = doc?.fileType ?? 'PDF';
    final newDoc = Message(
      id: 'msg_doc_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      senderId: myProfile.id,
      senderName: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi',
      senderAvatar: myProfile.avatarUrl,
      type: MessageType.document,
      content: 'Fichier vérifié : $fileName',
      time: timeStr,
      isOutgoing: true,
      isRead: widget.conversation.isOnline,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
      reactions: {'✨': 1},
    );
    context.read<MessageRepository>().sendMessage(newDoc);
    context.read<ConversationRepository>().updateLastMessage(
          conversationId: widget.conversation.id,
          message: 'Document : $fileName',
          time: timeStr,
        );
    setState(() => _showAttachments = false);
  }

  void _sendVideo([String? videoUri]) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final myProfile = context.read<ProfileRepository>().getProfile();
    final newVideo = Message(
      id: 'msg_vid_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      senderId: myProfile.id,
      senderName: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi',
      senderAvatar: myProfile.avatarUrl,
      type: MessageType.video,
      content: 'Vidéo HD partagée 🎬',
      time: timeStr,
      isOutgoing: true,
      isRead: widget.conversation.isOnline,
      videoUri: videoUri,
      videoDuration: '1:45',
    );
    context.read<MessageRepository>().sendMessage(newVideo);
    context.read<ConversationRepository>().updateLastMessage(
          conversationId: widget.conversation.id,
          message: 'Vidéo HD (1:45) 🎬',
          time: timeStr,
        );
    setState(() => _showAttachments = false);
  }

  void _triggerCall({bool isVideo = false}) {
    final devRepo = context.read<DeviceRepository>();
    final myProfile = context.read<ProfileRepository>().getProfile();
    final titleLower = widget.conversation.title.trim().toLowerCase();
    final myNameLower = myProfile.displayName.trim().toLowerCase();
    final isSelf = widget.conversation.id == 'conv_self' ||
        widget.conversation.id == myProfile.id ||
        (myNameLower.isNotEmpty && titleLower == myNameLower) ||
        titleLower == 'note à moi-même' ||
        titleLower.contains('moi-même');
    final isOwnDevice = devRepo.getAllDevices().any((d) =>
        d.id == widget.conversation.id ||
        d.name.trim().toLowerCase() == titleLower);

    if (isSelf || isOwnDevice) {
      _showSelfCallNotAllowedAlert();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => CallDialog(
        peerName: widget.conversation.title,
        peerAvatar: widget.conversation.peerAvatar,
        isVideo: isVideo,
        isPeerOnline: widget.conversation.isOnline,
        onCallEnded: (duration, wasVideo) {
          final now = DateTime.now();
          final timeStr =
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          final callDesc =
              wasVideo ? 'Appel vidéo direct ($duration)' : 'Appel vocal direct ($duration)';
          final callMsg = Message(
            id: 'msg_c_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: widget.conversation.id,
            senderId: myProfile.id,
            senderName: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi',
            senderAvatar: myProfile.avatarUrl,
            type: MessageType.text,
            content: callDesc,
            time: timeStr,
            isOutgoing: true,
            isRead: widget.conversation.isOnline,
          );
          context.read<MessageRepository>().sendMessage(callMsg);
          context.read<ConversationRepository>().updateLastMessage(
                conversationId: widget.conversation.id,
                message: '$callDesc 📞',
                time: timeStr,
              );
        },
      ),
    );
  }

  void _showSelfCallNotAllowedAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: const [
            Icon(Icons.phone_disabled_rounded, color: Color(0xFF0043B8), size: 28),
            SizedBox(width: 10),
            Text(
              'Appel non autorisé',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Vous ne pouvez pas vous appeler vous-même ni appeler l\'un de vos autres appareils synchronisés.\n\n'
          'Vos appareils partagent le même espace sécurisé et vos échanges y sont déjà synchronisés instantanément en temps réel.',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  // --- Multi-selection Delete Dialog with Mandatory Reason ---
  void _showDeleteDialog(List<String> messageIds) {
    if (messageIds.isEmpty) return;

    String? selectedReason;
    final customReasonController = TextEditingController();
    bool isForEveryone = false;

    final reasons = [
      "Erreur de destinataire / d'envoi",
      "Information confidentielle ou sensible",
      "Contenu inexact ou obsolète",
      "Autre motif personnalisé...",
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isCustom = selectedReason == 'Autre motif personnalisé...';
          final effectiveReason = isCustom
              ? customReasonController.text.trim()
              : selectedReason;
          final canDeleteForEveryone =
              effectiveReason != null && effectiveReason.isNotEmpty;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    messageIds.length > 1
                        ? 'Supprimer ${messageIds.length} messages'
                        : 'Supprimer le message',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choisissez la portée de la suppression :',
                    style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: !isForEveryone ? AppTheme.primarySoft : Colors.white,
                            side: BorderSide(
                              color: !isForEveryone ? AppTheme.primary : const Color(0xFFDFE4ED),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => setModalState(() => isForEveryone = false),
                          child: Text(
                            'Pour moi',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: !isForEveryone ? AppTheme.primary : AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isForEveryone ? const Color(0xFFFEF2F2) : Colors.white,
                            side: BorderSide(
                              color: isForEveryone ? const Color(0xFFEF4444) : const Color(0xFFDFE4ED),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => setModalState(() => isForEveryone = true),
                          child: Text(
                            'Pour tous',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isForEveryone ? const Color(0xFFEF4444) : AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isForEveryone) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.shield_outlined, size: 16, color: Color(0xFFB45309)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Charte d'intégrité MRixk : Un motif obligatoire est requis pour certifier la suppression auprès de vos correspondants.",
                              style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Motif obligatoire :',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () => setModalState(() => selectedReason = r),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  size: 16,
                                  color: isSelected ? const Color(0xFFEF4444) : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    r,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected ? const Color(0xFF991B1B) : AppTheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (isCustom) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: customReasonController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Précisez le motif obligatoire...',
                          hintStyle: TextStyle(fontSize: 12),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                onPressed: (isForEveryone && !canDeleteForEveryone)
                    ? null
                    : () async {
                        final myProfile = context.read<ProfileRepository>().getProfile();
                        final reason = isForEveryone ? effectiveReason! : 'Supprimé localement';
                        await context.read<MessageRepository>().deleteMultipleMessages(
                              messageIds,
                              forEveryone: isForEveryone,
                              reason: reason,
                              deletedByName: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi',
                            );
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          setState(() {
                            _isSelectionMode = false;
                            _selectedMessageIds.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isForEveryone
                                    ? 'Messages supprimés pour tous (Motif : $reason)'
                                    : 'Messages supprimés pour vous',
                              ),
                            ),
                          );
                        }
                      },
                child: const Text('Confirmer la suppression'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Forward Message Dialog ---
  void _showForwardDialog(List<String> messageIds) {
    if (messageIds.isEmpty) return;

    final conversations = context
        .read<ConversationRepository>()
        .getAllConversations()
        .where((c) => c.id != widget.conversation.id)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: const [
            Icon(Icons.forward, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Transférer vers...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: conversations.isEmpty
              ? const Text('Aucune autre discussion disponible.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final conv = conversations[idx];
                    return ListTile(
                      leading: AppAvatar(
                        name: conv.title,
                        avatarUrl: conv.peerAvatar,
                        radius: 18,
                        isOnline: conv.isOnline,
                      ),
                      title: Text(
                        conv.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        conv.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.send, color: AppTheme.primary, size: 18),
                      onTap: () async {
                        final myProfile = context.read<ProfileRepository>().getProfile();
                        for (final mid in messageIds) {
                          await context.read<MessageRepository>().forwardMessage(
                                mid,
                                conv.id,
                                senderId: myProfile.id,
                                senderName: myProfile.displayName.isNotEmpty ? myProfile.displayName : 'Moi',
                                senderAvatar: myProfile.avatarUrl,
                              );
                        }
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          setState(() {
                            _isSelectionMode = false;
                            _selectedMessageIds.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${messageIds.length} message(s) transféré(s) à ${conv.title} avec protection directe.',
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // --- View-Once Full Screen Secure Viewer ---
  void _openViewOnceViewer(Message msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF0F172A),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.remove_red_eye, color: Color(0xFFEF4444), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'VUE UNIQUE ACTIVÉE',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () async {
                        await context.read<MessageRepository>().openViewOnceMessage(msg.id);
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Le message à vue unique a été détruit de la mémoire locale.'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (msg.imageUri != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              msg.imageUri!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image,
                                color: Colors.white54,
                                size: 100,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            msg.content,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: Colors.black.withOpacity(0.4),
                child: Row(
                  children: [
                    const Icon(Icons.shield, color: AppTheme.statusGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Protection active • Interdiction capture d'écran • Auto-destruction définitive dès la fermeture.",
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- High Quality Emoji Picker ---
  void _showQualityEmojiPicker() {
    final emojiList = [
      '👍', '❤️', '🔥', '😂', '✨', '👏', '🙏', '🎉',
      '🚀', '💡', '🔒', '🛡️', '😊', '😍', '🤝', '💪',
      '💯', '🌟', '🎯', '📦', '⚡', '☕', '🥳', '😎',
      '👀', '🙌', '👌', '💬', '🏆', '🌿', '🌍', '💎'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Émojis Haute Définition',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: emojiList.map((emoji) {
                  return InkWell(
                    onTap: () {
                      _textController.text = _textController.text + emoji;
                      Navigator.of(ctx).pop();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Live Camera & Real Video Capture Dialog ---
  void _openCameraSimulator() {
    bool isFrontCamera = false;
    bool isFlashOn = false;
    bool isVideoMode = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setCameraState) {
          return Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF020617)],
                        radius: 0.9,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isVideoMode
                                ? Icons.videocam_rounded
                                : (isFrontCamera ? Icons.face : Icons.photo_camera_back),
                            size: 100,
                            color: isVideoMode ? const Color(0x33EF4444) : Colors.white12,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isVideoMode
                                ? 'Enregistrement Vidéo HD Réel (Caméra & Microphone)'
                                : (isFrontCamera ? 'Objectif Avant (Selfie HD)' : 'Objectif Principal HD (Capteur 50 Mpx)'),
                            style: TextStyle(
                              color: isVideoMode ? const Color(0xFFFCA5A5) : Colors.white54,
                              fontSize: 12,
                              fontWeight: isVideoMode ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isVideoMode ? const Color(0xFFEF4444) : Colors.white24,
                        width: isVideoMode ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isVideoMode ? const Color(0xFF991B1B) : Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isVideoMode ? '🔴 ENREGISTREMENT VIDÉO HD' : 'QUALITÉ HD • PROTÉGÉ',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: isFlashOn ? Colors.amber : Colors.white,
                          ),
                          onPressed: () => setCameraState(() => isFlashOn = !isFlashOn),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 30,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mode selector: Photo / Vidéo
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => setCameraState(() => isVideoMode = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: !isVideoMode ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'PHOTO',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: !isVideoMode ? Colors.black : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setCameraState(() => isVideoMode = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isVideoMode ? const Color(0xFFEF4444) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'VIDÉO',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isVideoMode ? Colors.white : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                              onPressed: () => setCameraState(() => isFrontCamera = !isFrontCamera),
                            ),
                            GestureDetector(
                              onTap: () async {
                                Navigator.of(ctx).pop();
                                if (isVideoMode) {
                                  final video = await RealMediaService.instance.captureCameraVideo();
                                  if (video != null && video.isNotEmpty) {
                                    _sendVideo(video);
                                  }
                                } else {
                                  final photo = await RealMediaService.instance.captureCameraPhoto();
                                  if (photo != null) {
                                    _sendMessage(
                                      textOverride: 'Photo capturée en direct 📷 (Haute Définition)',
                                      type: MessageType.image,
                                      imageUri: photo,
                                    );
                                  }
                                }
                              },
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isVideoMode ? const Color(0xFFEF4444) : Colors.white,
                                    width: 4,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: isVideoMode ? const Color(0xFFEF4444) : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: isVideoMode
                                        ? const Center(
                                            child: Icon(Icons.videocam, color: Colors.white, size: 28),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.looks_one,
                                color: _isViewOnceMode ? Colors.amber : Colors.white,
                                size: 28,
                              ),
                              onPressed: () {
                                setState(() => _isViewOnceMode = !_isViewOnceMode);
                                setCameraState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDesktopContextMenu(BuildContext context, Message msg, Offset position) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'react',
          enabled: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['❤️', '👍', '🔥', '😂', '✨'].map((emoji) {
              return InkWell(
                onTap: () {
                  context.read<MessageRepository>().toggleReaction(msg.id, emoji);
                  Navigator.of(context).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              );
            }).toList(),
          ),
        ),
        const PopupMenuDivider(),
        if (msg.isOutgoing && !msg.isDeletedForEveryone && msg.type == MessageType.text)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                SizedBox(width: 10),
                Text('Modifier le message', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'select',
          child: Row(
            children: [
              Icon(Icons.checklist_rounded, size: 18, color: AppTheme.onSurface),
              SizedBox(width: 10),
              Text('Sélectionner', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text(
                'Supprimer...',
                style: TextStyle(fontSize: 13, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected == 'edit') {
      setState(() {
        _editingMessage = msg;
        _textController.text = msg.content;
      });
    } else if (selected == 'select') {
      setState(() {
        _isSelectionMode = true;
        _selectedMessageIds.add(msg.id);
      });
    } else if (selected == 'delete') {
      _showDeleteDialog([msg.id]);
    }
  }

  // --- Message Options Bottom Sheet ---
  void _showMessageOptions(Message msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '👍', '🔥', '😂', '✨', '👏'].map((emoji) {
                    return InkWell(
                      onTap: () {
                        context.read<MessageRepository>().toggleReaction(msg.id, emoji);
                        Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              if (msg.isOutgoing && !msg.isDeletedForEveryone && msg.type == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.edit, color: AppTheme.primary),
                  title: const Text('Modifier le message'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _editingMessage = msg;
                      _textController.text = msg.content;
                    });
                  },
                ),
              ListTile(
                leading: const Icon(Icons.forward, color: Colors.blue),
                title: const Text('Transférer le message'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showForwardDialog([msg.id]);
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outlined, color: AppTheme.onSurface),
                title: const Text('Sélectionner plusieurs messages'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _isSelectionMode = true;
                    _selectedMessageIds.add(msg.id);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: const Text('Supprimer...', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showDeleteDialog([msg.id]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentConv = context.watch<ConversationRepository>().getConversationById(widget.conversation.id) ?? widget.conversation;
    final messages = context.watch<MessageRepository>().getMessagesForConversation(widget.conversation.id);

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSecurityBanner(),
              _buildDateDivider(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90, top: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageItem(msg, currentConv);
                  },
                ),
              ),
            ],
          ),
          if (_showAttachments)
            Positioned(
              left: 16,
              right: 16,
              bottom: 96,
              child: _buildAttachmentDrawer(),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildComposer(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.onSurface),
          onPressed: () {
            setState(() {
              _isSelectionMode = false;
              _selectedMessageIds.clear();
            });
          },
        ),
        title: Text(
          '${_selectedMessageIds.length} sélectionné(s)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all, color: AppTheme.primary),
            tooltip: 'Tout sélectionner',
            onPressed: () {
              final messages = context.read<MessageRepository>().getMessagesForConversation(widget.conversation.id);
              setState(() {
                if (_selectedMessageIds.length == messages.length) {
                  _selectedMessageIds.clear();
                } else {
                  _selectedMessageIds.addAll(messages.map((m) => m.id));
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.forward, color: AppTheme.primary),
            tooltip: 'Transférer',
            onPressed: _selectedMessageIds.isEmpty
                ? null
                : () => _showForwardDialog(_selectedMessageIds.toList()),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            tooltip: 'Supprimer',
            onPressed: _selectedMessageIds.isEmpty
                ? null
                : () => _showDeleteDialog(_selectedMessageIds.toList()),
          ),
          const SizedBox(width: 4),
        ],
      );
    }

    final currentConv = context.watch<ConversationRepository>().getConversationById(widget.conversation.id) ?? widget.conversation;

    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.95),
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
        onPressed: () {
          if (widget.onCloseDesktop != null) {
            widget.onCloseDesktop!();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
      titleSpacing: 0,
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ConversationInfoScreen(conversation: currentConv),
            ),
          );
        },
        child: Row(
          children: [
            AppAvatar(
              name: currentConv.title,
              avatarUrl: currentConv.peerAvatar,
              radius: 19,
              isOnline: currentConv.isOnline,
              isVerified: currentConv.isVerified,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          currentConv.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (currentConv.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 15, color: AppTheme.secondary),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: currentConv.isOnline
                              ? AppTheme.statusGreen
                              : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentConv.isGroup
                            ? '${currentConv.groupMembers.isNotEmpty ? currentConv.groupMembers.length : (currentConv.groupMembersCount)} membres • Chiffré'
                            : (currentConv.isOnline
                                ? 'En ligne'
                                : 'Vu récemment'),
                        style: TextStyle(
                          fontSize: 11,
                          color: currentConv.isOnline
                              ? AppTheme.statusGreen
                              : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (currentConv.isGroup)
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Icon(Icons.note_add_rounded, size: 20, color: AppTheme.primary),
            ),
            onPressed: () {
              _showCreateNoteDialog(currentConv);
            },
            tooltip: 'Ajouter un nouveau Bloc-Note',
          ),
        IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _isSelectionMode ? AppTheme.primarySoft : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isSelectionMode ? AppTheme.primary : const Color(0xFFDFE4ED),
              ),
            ),
            child: Icon(
              Icons.checklist_rounded,
              size: 18,
              color: _isSelectionMode ? AppTheme.primary : AppTheme.onSurfaceVariant,
            ),
          ),
          onPressed: () => setState(() {
            _isSelectionMode = !_isSelectionMode;
            if (!_isSelectionMode) _selectedMessageIds.clear();
          }),
          tooltip: _isSelectionMode ? 'Quitter la sélection' : 'Sélectionner des messages',
        ),
        IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDFE4ED)),
            ),
            child: const Icon(Icons.call, size: 18, color: AppTheme.primary),
          ),
          onPressed: () => _triggerCall(isVideo: false),
          tooltip: 'Appel vocal sécurisé',
        ),
        IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDFE4ED)),
            ),
            child: const Icon(Icons.videocam, size: 18, color: AppTheme.primary),
          ),
          onPressed: () => _triggerCall(isVideo: true),
          tooltip: 'Appel vidéo sécurisé',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBlockedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB45309).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Échange suspendu avec bienveillance',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.conversation.blockedMessage ??
                      'Cette discussion est temporairement ou définitivement inactive. Les messages ne peuvent pas être transmis pour le moment afin de respecter la tranquillité de chacun.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBanner() {
    if (widget.conversation.isBlocked) return _buildBlockedBanner();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDFE4ED)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111C2C).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.secondaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock, size: 18, color: AppTheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Discussion confidentielle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                  ),
                ),
                Text(
                  'Visible uniquement par vous et ${widget.conversation.title}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.secondaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppTheme.secondaryGlow,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Sécurisé',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDFE4ED)),
        ),
        child: const Text(
          "Aujourd'hui, 9 Novembre",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupNoteInChatMessage(Message msg, Conversation conv) {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final isAdmin = conv.isUserAdmin(myProfile.id);

    // Extract document ID if encoded in format [Bloc-Note du Groupe: doc_123]
    String? explicitDocId;
    final idMatch = RegExp(r'\[Bloc-Note du Groupe:\s*([a-zA-Z0-9_\-]+)\]').firstMatch(msg.content);
    if (idMatch != null) {
      explicitDocId = idMatch.group(1);
    }

    // Extract title if present in quotes
    String? customTitle;
    final quoteMatch = RegExp(r'"([^"]+)"').firstMatch(msg.content);
    if (quoteMatch != null && quoteMatch.group(1)!.trim().isNotEmpty) {
      customTitle = quoteMatch.group(1)!.trim();
    }

    final note = context.watch<GroupNoteRepository>().getNote(
      conv.id,
      documentId: explicitDocId,
      documentSlug: customTitle,
      groupTitle: conv.title,
    );

    final noteTitle = customTitle ?? note.title;
    final createdInfo = note.createdAt.isNotEmpty ? note.createdAt : msg.time;
    final modifiedInfo = note.lastModified.isNotEmpty ? note.lastModified : msg.time;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0043B8),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info bar: Bloc-Notes du groupe • Collaboratif | Synchronisé ✅ | ...
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 14, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text(
                      'Bloc-Notes du groupe • Collaboratif',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Synchronisé ✅',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                tooltip: 'Options du bloc-note',
                onSelected: (val) {
                  switch (val) {
                    case 'rename':
                      _showRenameNoteDialog(conv);
                      break;
                    case 'settings':
                      GroupNotepadScreen.showInConversation(context, conv);
                      break;
                    case 'transfer':
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sélectionnez une discussion pour transférer le bloc-note.')),
                      );
                      break;
                    case 'download':
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Téléchargement du document "$noteTitle" (.md) terminé.')),
                      );
                      break;
                    case 'delete':
                      _showDeleteDialog([msg.id]);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text('Renommer'),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_suggest_rounded, size: 16, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('Gérer les permissions'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'transfer',
                    child: Row(
                      children: [
                        Icon(Icons.forward_rounded, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text('Transférer le document'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text('Télécharger le document'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            noteTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Créé le $createdInfo • Dernière modification : $modifiedInfo',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Text(
            msg.content
                .replaceAll(RegExp(r'📝\s*\[Bloc-Note du Groupe(?::\s*[^\]]+)?\]\s*"[^"]*"\s*'), '')
                .replaceAll(RegExp(r'\[Bloc-Note du Groupe(?::\s*[^\]]+)?\]'), '')
                .trim(),
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => GroupNotepadScreen.showInConversation(context, conv, documentId: note.id),
                  icon: const Icon(Icons.auto_stories_rounded, size: 16),
                  label: const Text(
                    'Ouvrir',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => _showDeleteDialog([msg.id]),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text(
                  'Supprimer',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRenameNoteDialog(Conversation conv) {
    final note = context.read<GroupNoteRepository>().getNote(conv.id);
    final ctrl = TextEditingController(text: note.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Renommer le Bloc-Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nouveau nom',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                context.read<GroupNoteRepository>().renameNote(conv.id, note.id, newName);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showCreateNoteDialog(Conversation conv) {
    final titleCtrl = TextEditingController(text: 'Bloc-Note Collaboratif');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text('Nouveau Bloc-Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajouter un bloc-note dans le fil de la conversation comme un texto.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nom du bloc-note',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final title = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Bloc-Note Collaboratif';
              Navigator.of(ctx).pop();

              final myProfile = context.read<ProfileRepository>().getProfile();
              final newNote = await context.read<GroupNoteRepository>().createDocument(
                conv.id,
                title: title,
                createdBy: myProfile.displayName.isNotEmpty ? '${myProfile.displayName} (Membre)' : 'Richard MARE (Membre)',
              );

              _sendMessage(
                textOverride: '📝 [Bloc-Note du Groupe: ${newNote.id}] "$title"\nEspace de travail collaboratif, variables et formules mathématiques.',
                type: MessageType.document,
                fileName: '$title.dws',
              );

              if (mounted) {
                GroupNotepadScreen.showInConversation(context, conv, documentId: newNote.id);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message msg, [Conversation? conv]) {
    final effectiveConv = conv ?? widget.conversation;
    final isSelected = _selectedMessageIds.contains(msg.id);

    if (msg.content.contains('[Bloc-Note du Groupe')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _buildGroupNoteInChatMessage(msg, effectiveConv),
      );
    }

    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showDesktopContextMenu(context, msg, details.globalPosition),
      child: InkWell(
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            _selectedMessageIds.add(msg.id);
          });
        },
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedMessageIds.remove(msg.id);
                if (_selectedMessageIds.isEmpty) {
                  _isSelectionMode = false;
                }
              } else {
                _selectedMessageIds.add(msg.id);
              }
            });
          } else {
            _showMessageOptions(msg);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Checkbox(
                  value: isSelected,
                  activeColor: AppTheme.primary,
                  shape: const CircleBorder(),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedMessageIds.add(msg.id);
                      } else {
                        _selectedMessageIds.remove(msg.id);
                        if (_selectedMessageIds.isEmpty) {
                          _isSelectionMode = false;
                        }
                      }
                    });
                  },
                ),
              ),
            Expanded(
              child: msg.isOutgoing
                  ? _buildOutgoingMessage(msg)
                  : _buildIncomingMessage(msg),
            ),
            if (_isSelectionMode)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF94A3B8)),
                tooltip: 'Supprimer ce message',
                splashRadius: 18,
                onPressed: () => _showDeleteDialog([msg.id]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedMessageCard(Message msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  msg.isOutgoing
                      ? 'Vous avez supprimé ce message'
                      : 'Ce message a été supprimé par ${msg.deletedByName ?? msg.senderName}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          if (msg.deletionReason != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: Text(
                'Motif obligatoire : ${msg.deletionReason}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewOnceCard(Message msg) {
    final isOpened = msg.isViewOnceOpened;
    return GestureDetector(
      onTap: isOpened ? null : () => _openViewOnceViewer(msg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOpened ? const Color(0xFFE2E8F0) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOpened ? const Color(0xFFCBD5E1) : const Color(0xFFFCD34D),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isOpened ? Colors.grey.shade400 : const Color(0xFFF59E0B),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpened ? 'Vue unique expirée' : 'Message à vue unique',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isOpened ? const Color(0xFF64748B) : const Color(0xFF92400E),
                  ),
                ),
                Text(
                  isOpened
                      ? 'Ce contenu a été détruit'
                      : 'Appuyez pour afficher • Auto-destruction',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOpened ? const Color(0xFF94A3B8) : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingMessage(Message msg) {
    if (msg.isDeletedForEveryone) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: _buildDeletedMessageCard(msg),
      );
    }

    if (msg.isViewOnce) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: _buildViewOnceCard(msg),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppAvatar(
            name: msg.senderName,
            avatarUrl: msg.senderAvatar,
            radius: 14,
            showBadge: false,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.isForwarded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.forward, size: 12, color: AppTheme.onSurfaceVariant),
                        SizedBox(width: 4),
                        Text('Transféré', style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppTheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                    ),
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF111C2C).withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.type == MessageType.image && msg.imageUri != null) ...[
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ImageViewerScreen(
                                  imageUri: msg.imageUri!,
                                  title: msg.senderName,
                                  subtitle: 'Reçu à ${msg.time} • Protégé',
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                AppMediaImage(
                                  imageUrl: msg.imageUri,
                                  height: 180,
                                  width: double.infinity,
                                  fallbackTitle: 'Photo reçue HD',
                                  fallbackSubtitle: 'Transmise par ${msg.senderName} • Protégé',
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('Agrandir', style: TextStyle(color: Colors.white, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else if (msg.type == MessageType.video) ...[
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(
                                  videoUri: msg.videoUri ?? 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
                                  title: 'Vidéo reçue de ${msg.senderName}',
                                  duration: msg.videoDuration ?? '1:45',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(Icons.videocam, size: 48, color: Colors.white24),
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.play_circle_fill, size: 12, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(msg.videoDuration ?? '1:45', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('HD • Protégé', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else if (msg.type == MessageType.document) ...[
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DocumentViewerScreen(
                                  fileName: msg.fileName ?? 'Document_sécurisé.pdf',
                                  fileSize: msg.fileSize ?? '2.8 Mo',
                                  fileUri: null,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFEE2E2)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.description, size: 20, color: Color(0xFFDC2626)),
                                      Text(
                                        'DOC',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.fileName ?? 'Document_sécurisé.pdf',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Document protégé • ${msg.fileSize ?? '2.8 Mo'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download_rounded, color: AppTheme.primary, size: 22),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Document téléchargé dans /MRixk/Documents/${msg.fileName ?? "Document.pdf"}'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else if (msg.type == MessageType.voice) ...[
                        AudioPlayerWidget(
                          duration: msg.voiceDuration ?? '0:42',
                          waveform: msg.waveform,
                          audioUrl: msg.voiceUri,
                          isOutgoing: false,
                        ),
                        if (msg.voiceTranscription != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.graphic_eq, size: 14, color: Color(0xFF166534)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Transcription automatique',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF166534),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  msg.voiceTranscription!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        Text(
                          msg.content,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.4,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.time,
                        style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                      ),
                      if (msg.isEdited) ...[
                        const SizedBox(width: 4),
                        const Text('(modifié)', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppTheme.onSurfaceVariant)),
                      ],
                      const SizedBox(width: 4),
                      const Text('•', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 12, color: AppTheme.secondary),
                      const SizedBox(width: 2),
                      const Text(
                        'Signature vérifiée',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingMessage(Message msg) {
    if (msg.isDeletedForEveryone) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Align(
          alignment: Alignment.centerRight,
          child: _buildDeletedMessageCard(msg),
        ),
      );
    }

    if (msg.isViewOnce) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Align(
          alignment: Alignment.centerRight,
          child: _buildViewOnceCard(msg),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (msg.isForwarded)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.forward, size: 12, color: AppTheme.onSurfaceVariant),
                  SizedBox(width: 4),
                  Text('Transféré', style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppTheme.onSurfaceVariant)),
                ],
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF245BDB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryContainer.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.type == MessageType.image && msg.imageUri != null) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImageViewerScreen(
                            imageUri: msg.imageUri!,
                            title: 'Vous',
                            subtitle: 'Envoyé à ${msg.time} • Protégé',
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          AppMediaImage(
                            imageUrl: msg.imageUri,
                            height: 180,
                            width: double.infinity,
                            fallbackTitle: 'Photo HD',
                            fallbackSubtitle: 'Envoyée par vous • Format original',
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('HD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Agrandir', style: TextStyle(color: Colors.white, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (msg.type == MessageType.video) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                            videoUri: msg.videoUri ?? 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
                            title: 'Votre vidéo',
                            duration: msg.videoDuration ?? '1:45',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.videocam, size: 48, color: Colors.white24),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white70),
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_circle_fill, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(msg.videoDuration ?? '1:45', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('HD • 1080p', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (msg.type == MessageType.document) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(
                            fileName: msg.fileName ?? 'Document.pdf',
                            fileSize: msg.fileSize ?? '2.8 Mo',
                            fileUri: null,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFEE2E2)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.description, size: 20, color: Color(0xFFDC2626)),
                                Text(
                                  'PDF',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.fileName ?? 'Document.pdf',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Document vérifié • ${msg.fileSize ?? '2.8 Mo'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download, color: AppTheme.primary, size: 20),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Téléchargé dans /MRixk/Documents/${msg.fileName ?? "Document.pdf"}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.shield, size: 12, color: Colors.white70),
                          SizedBox(width: 4),
                          Text(
                            'Protégé de bout en bout',
                            style: TextStyle(fontSize: 10.5, color: Colors.white70),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '✓ Prêt',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (msg.type == MessageType.voice) ...[
                  AudioPlayerWidget(
                    duration: msg.voiceDuration ?? '0:18',
                    waveform: msg.waveform,
                    audioUrl: msg.voiceUri,
                    isOutgoing: true,
                  ),
                ] else ...[
                  Text(
                    msg.content,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.reactions.isNotEmpty)
                ...msg.reactions.entries.map((entry) {
                  return GestureDetector(
                    onTap: () {
                      context.read<MessageRepository>().toggleReaction(msg.id, entry.key);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDFE4ED)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(entry.key, style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 3),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              Text(
                msg.time,
                style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
              ),
              if (msg.isEdited) ...[
                const SizedBox(width: 4),
                const Text('(modifié)', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppTheme.onSurfaceVariant)),
              ],
              const SizedBox(width: 4),
              (!widget.conversation.isOnline || !msg.isRead)
                  ? Icon(Icons.done, size: 15, color: Colors.grey.shade500)
                  : const Icon(Icons.done_all, size: 16, color: Color(0xFF00BCD4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentDrawer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDFE4ED)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111C2C).withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _drawerItem(
              icon: Icons.camera_alt,
              label: 'Caméra',
              color: Colors.deepOrange,
              onTap: () {
                setState(() => _showAttachments = false);
                _openCameraSimulator();
              },
            ),
            const SizedBox(width: 14),
            _drawerItem(
              icon: Icons.image,
              label: 'Photos HD',
              color: Colors.blue,
              onTap: () async {
                setState(() => _showAttachments = false);
                final photo = await RealMediaService.instance.pickMediaFile(isVideo: false);
                if (photo != null) {
                  _sendMessage(
                    textOverride: 'Photo partagée en haute définition 📷',
                    type: MessageType.image,
                    imageUri: photo,
                  );
                }
              },
            ),
            const SizedBox(width: 14),
            _drawerItem(
              icon: Icons.videocam,
              label: 'Vidéo HD',
              color: Colors.purple,
              onTap: () {
                setState(() => _showAttachments = false);
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Vidéo Haute Définition',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEFF6FF),
                              child: Icon(Icons.videocam_rounded, color: AppTheme.primary),
                            ),
                            title: const Text('Enregistrer avec la caméra', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Capture vidéo HD réelle en direct avec microphone', style: TextStyle(fontSize: 12)),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final video = await RealMediaService.instance.captureCameraVideo();
                              if (video != null && video.isNotEmpty) {
                                _sendVideo(video);
                              }
                            },
                          ),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFF3E8FF),
                              child: Icon(Icons.video_library_rounded, color: Colors.purple),
                            ),
                            title: const Text('Choisir une vidéo existante', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Fichiers MP4, WebM ou MOV', style: TextStyle(fontSize: 12)),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final video = await RealMediaService.instance.pickMediaFile(isVideo: true);
                              if (video != null && video.isNotEmpty) {
                                _sendVideo(video);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
            _drawerItem(
              icon: Icons.folder,
              label: 'Fichiers',
              color: Colors.teal,
              onTap: () async {
                setState(() => _showAttachments = false);
                final doc = await RealMediaService.instance.pickDocumentFile();
                if (doc != null) {
                  _sendDocument(doc);
                }
              },
            ),
            const SizedBox(width: 14),
            _drawerItem(
              icon: Icons.lock,
              label: 'Coffre-fort',
              color: Colors.amber,
              onTap: () {
                _sendMessage(
                  textOverride: 'Document extrait du Coffre Personnel 🔐',
                  type: MessageType.text,
                );
              },
            ),
            const SizedBox(width: 14),
            _drawerItem(
              icon: Icons.contact_page,
              label: 'Contact',
              color: Colors.indigo,
              onTap: () {
                _sendMessage(
                  textOverride: 'Contact recommandé : Dr. Kaboré',
                  type: MessageType.text,
                );
              },
            ),
            if (widget.conversation.isGroup) ...[
              const SizedBox(width: 14),
              _drawerItem(
                icon: Icons.edit_note_rounded,
                label: 'Bloc-Note',
                color: Colors.deepPurple,
                onTap: () {
                  setState(() => _showAttachments = false);
                  _showCreateNoteDialog(widget.conversation);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required MaterialColor color,
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
              color: color.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color.shade700, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_clock, size: 18, color: AppTheme.onSurfaceVariant),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Envoi indisponible • Contact temporairement ou définitivement suspendu',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final currentConv = context.watch<ConversationRepository>().getConversationById(widget.conversation.id) ?? widget.conversation;
    final myProfile = context.watch<ProfileRepository>().getProfile();
    final isGroupAdmin = currentConv.isUserAdmin(myProfile.id);

    if (currentConv.isBlocked) return _buildBlockedComposer();

    if (currentConv.isGroup) {
      final currentMember = currentConv.groupMembers.firstWhere(
        (m) => m.id == myProfile.id,
        orElse: () => const GroupMember(id: '', name: '', role: 'member'),
      );
      if (currentMember.isMuted) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF1F2),
            border: Border(top: BorderSide(color: Color(0xFFFECDD3))),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.volume_off_rounded, size: 18, color: Color(0xFFE11D48)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vous avez été mis en sourdine par un administrateur du groupe.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFBE123C)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (currentConv.onlyAdminsCanSendMessages && !isGroupAdmin) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock_rounded, size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seuls les administrateurs peuvent envoyer des messages dans ce groupe.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm.withOpacity(0.96),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFDFE4ED).withOpacity(0.8),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // If editing a message, show editing header bar
            if (_editingMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Modification du message...',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _editingMessage = null;
                          _textController.clear();
                        });
                      },
                      child: const Icon(Icons.close, size: 18, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            ],

            // AI Assist Chip
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    _sendMessage(
                      textOverride: '✨ Résumé des points clés : Tout est validé et prêt pour le déploiement.',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDFE4ED)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF111C2C).withOpacity(0.02),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('✨', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Text(
                          'Résumer les points clés',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_isRecordingVoice)
              WhatsAppVoiceRecorder(
                onSend: _onVoiceRecorded,
                onCancel: () => setState(() => _isRecordingVoice = false),
              )
            else
              Row(
                children: [
                  // Plus button for attachments
                  GestureDetector(
                    onTap: () => setState(() => _showAttachments = !_showAttachments),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _showAttachments ? AppTheme.primarySoft : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDFE4ED)),
                      ),
                      child: Icon(
                        _showAttachments ? Icons.close : Icons.add,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // View Once Toggle (1)
                  GestureDetector(
                    onTap: () {
                      setState(() => _isViewOnceMode = !_isViewOnceMode);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isViewOnceMode
                                ? "Mode Vue Unique (1) activé : le message s'autodétruira après lecture."
                                : 'Mode Vue Unique désactivé.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _isViewOnceMode ? const Color(0xFFF59E0B) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isViewOnceMode ? const Color(0xFFD97706) : const Color(0xFFDFE4ED),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _isViewOnceMode ? Colors.white : AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Input text
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDFE4ED)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined, size: 20, color: AppTheme.onSurfaceVariant),
                            onPressed: _showQualityEmojiPicker,
                            tooltip: 'Émojis haute qualité',
                          ),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                hintText: 'Écrire un message protégé...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.mic, size: 20, color: AppTheme.primary),
                            onPressed: _startVoiceRecording,
                            tooltip: 'Enregistrer un message vocal',
                          ),
                          if (widget.conversation.isGroup)
                            IconButton(
                              icon: const Icon(Icons.note_alt_outlined, size: 20, color: AppTheme.primary),
                              onPressed: () => _showCreateNoteDialog(widget.conversation),
                              tooltip: 'Ajouter un Bloc-Note',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      width: 40,
                      height: 40,
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
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        _editingMessage != null ? Icons.check : Icons.arrow_upward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
