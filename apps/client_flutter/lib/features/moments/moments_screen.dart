import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/moment.dart';
import '../../core/repositories/moment_repository.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_media_image.dart';
import '../discussions/widgets/audio_player_widget.dart';
import '../viewers/image_viewer_screen.dart';
import '../viewers/video_player_screen.dart';
import 'widgets/add_moment_dialog.dart';

class MomentsScreen extends StatelessWidget {
  const MomentsScreen({super.key});

  void _openAddMoment(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const AddMomentDialog(),
    );
  }

  void _showMomentOptionsMenu(BuildContext context, Moment moment) {
    final myProfile = context.read<ProfileRepository>().getProfile();
    final isAuthor = moment.authorId == myProfile.id ||
        (myProfile.displayName.isNotEmpty &&
            moment.authorName.toLowerCase() == myProfile.displayName.toLowerCase());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined, color: AppTheme.primary),
                title: const Text('Partager le moment'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lien du moment chiffré prêt au partage')),
                  );
                },
              ),
              if (isAuthor) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                  title: const Text('Modifier la légende'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditCaptionDialog(context, moment);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                  title: const Text('Supprimer le moment', style: TextStyle(color: Color(0xFFEF4444))),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await context.read<MomentRepository>().deleteMoment(moment.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Moment supprimé')),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditCaptionDialog(BuildContext context, Moment moment) {
    final controller = TextEditingController(text: moment.caption);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifier la légende', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Nouvelle légende...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isNotEmpty) {
                await context.read<MomentRepository>().updateMoment(moment.copyWith(caption: newText));
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showCommentsBottomSheet(BuildContext context, Moment moment) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final liveMoment = context.watch<MomentRepository>().getMomentById(moment.id) ?? moment;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Commentaires (${liveMoment.comments.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: liveMoment.comments.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: AppEmptyState(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'Aucun commentaire',
                                message: 'Soyez le premier à réagir à ce statut !',
                                iconSize: 28,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: liveMoment.comments.length,
                            separatorBuilder: (_, __) => const Divider(height: 12),
                            itemBuilder: (context, index) {
                              final comment = liveMoment.comments[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppAvatar(
                                    name: comment.authorName,
                                    avatarUrl: comment.authorAvatar,
                                    radius: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              comment.authorName,
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              comment.timeAgo,
                                              style: const TextStyle(fontSize: 10.5, color: AppTheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(comment.text, style: const TextStyle(fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      context.read<MomentRepository>().toggleCommentLike(moment.id, comment.id);
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          comment.userLiked ? Icons.favorite : Icons.favorite_border,
                                          size: 16,
                                          color: comment.userLiked ? Colors.redAccent : AppTheme.onSurfaceVariant,
                                        ),
                                        if (comment.likes > 0) ...[
                                          const SizedBox(width: 4),
                                          Text('${comment.likes}', style: const TextStyle(fontSize: 11)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  // Comment input bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: 'Écrire un commentaire chiffré...',
                            hintStyle: const TextStyle(fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (text) async {
                            if (text.trim().isNotEmpty) {
                              await context.read<MomentRepository>().addComment(moment.id, text);
                              commentController.clear();
                              setSheetState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                        onPressed: () async {
                          final text = commentController.text.trim();
                          if (text.isNotEmpty) {
                            await context.read<MomentRepository>().addComment(moment.id, text);
                            commentController.clear();
                            setSheetState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final momentRepo = context.watch<MomentRepository>();
    final moments = momentRepo.getAllMoments();

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Moments & Statuts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
                Text(
                  'Histoires chiffrées de bout en bout • 24h',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Icon(Icons.add, color: AppTheme.primary, size: 20),
                ),
                tooltip: 'Ajouter un moment / statut',
                onPressed: () => _openAddMoment(context),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Moments Feed or Coherent Empty State
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: moments.isEmpty
                ? SliverToBoxAdapter(
                    child: AppEmptyState(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Aucun statut pour l\'instant',
                      message:
                          'Partagez un moment éphémère (photo, vidéo ou note vocale) avec vos proches.',
                      actionLabel: 'Créer un statut',
                      onAction: () => _openAddMoment(context),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final moment = moments[index];
                        return _buildMomentCard(context, moment);
                      },
                      childCount: moments.length,
                    ),
                  ),
          ),
          // Bottom spacing so cards and button are completely clear of the floating navigation bar
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84.0),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF0043B8),
          elevation: 6,
          onPressed: () => _openAddMoment(context),
          tooltip: 'Nouveau Moment / Statut',
          child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildMomentCard(BuildContext context, Moment moment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      name: moment.authorName,
                      avatarUrl: moment.authorAvatar,
                      radius: 20,
                      isVerified: moment.authorBadge == 'verified',
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              moment.authorName,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            if (moment.authorBadge == 'verified') ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, size: 15, color: AppTheme.secondary),
                            ] else if (moment.authorBadge == 'Conseil') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Conseil',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ] else if (moment.authorBadge == 'stars') ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.stars, size: 15, color: AppTheme.primary),
                            ],
                          ],
                        ),
                        Text(
                          moment.timeAgo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: AppTheme.onSurfaceVariant),
                  tooltip: 'Options du moment',
                  onPressed: () => _showMomentOptionsMenu(context, moment),
                ),
              ],
            ),
          ),

          // Content body based on type
          if (moment.type == MomentType.image && moment.mediaUrl != null) ...[
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ImageViewerScreen(
                      imageUri: moment.mediaUrl!,
                      title: moment.authorName,
                      subtitle: moment.location ?? moment.timeAgo,
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: AppMediaImage(
                      imageUrl: moment.mediaUrl,
                      fallbackTitle: moment.authorName,
                      fallbackSubtitle: moment.location ?? 'Moment éphémère protégé',
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  if (moment.location != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wb_twilight, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              moment.location!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (moment.type == MomentType.video) ...[
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(
                      videoUri: moment.mediaUrl ?? 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
                      title: 'Vidéo partagée par ${moment.authorName}',
                      duration: '0:30',
                    ),
                  ),
                );
              },
              child: Container(
                height: 200,
                width: double.infinity,
                color: const Color(0xFF0F172A),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AppMediaImage(
                      imageUrl: moment.mediaUrl,
                      fit: BoxFit.cover,
                      fallbackTitle: 'Vidéo Haute Définition',
                      fallbackSubtitle: 'Appuyez pour lire en plein écran',
                      borderRadius: BorderRadius.zero,
                    ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (moment.type == MomentType.voice) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: AudioPlayerWidget(
                duration: moment.voiceDuration ?? '00:22',
              ),
            ),
            const SizedBox(height: 8),
          ] else if (moment.type == MomentType.quote) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE6F8F5), Color(0xFFF0FDF4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF74F8E3).withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote, size: 28, color: AppTheme.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      moment.caption,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Caption (if not already displayed in quote card)
          if (moment.type != MomentType.quote)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                moment.caption,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppTheme.onSurface,
                ),
              ),
            ),

          // Reactions & Comments Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Like button (toggles on/off, no indefinite increment!)
                    _reactionBubble(
                      icon: Icons.favorite,
                      count: moment.heartCount,
                      isActive: moment.userReaction == 'heart' || moment.userLiked,
                      activeColor: Colors.redAccent,
                      onTap: () {
                        context.read<MomentRepository>().toggleReaction(moment.id, 'heart');
                      },
                    ),
                    const SizedBox(width: 6),
                    // Mood reaction (toggles on/off!)
                    _reactionBubble(
                      icon: Icons.mood,
                      count: moment.moodCount,
                      isActive: moment.userReaction == 'mood',
                      activeColor: const Color(0xFFF59E0B),
                      onTap: () {
                        context.read<MomentRepository>().toggleReaction(moment.id, 'mood');
                      },
                    ),
                    const SizedBox(width: 6),
                    // Celebration reaction (toggles on/off!)
                    _reactionBubble(
                      icon: Icons.celebration,
                      count: moment.celebrationCount,
                      isActive: moment.userReaction == 'celebration',
                      activeColor: AppTheme.primary,
                      onTap: () {
                        context.read<MomentRepository>().toggleReaction(moment.id, 'celebration');
                      },
                    ),
                  ],
                ),
                // Comment button (opens comments list with comments reactions!)
                GestureDetector(
                  onTap: () => _showCommentsBottomSheet(context, moment),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 14, color: AppTheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${moment.comments.isNotEmpty ? moment.comments.length : moment.commentCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reactionBubble({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? (activeColor ?? AppTheme.primary).withOpacity(0.12) : AppTheme.surfaceWarm,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? (activeColor ?? AppTheme.primary).withOpacity(0.5) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? (activeColor ?? AppTheme.primary) : AppTheme.onSurfaceVariant,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? (activeColor ?? AppTheme.primary) : AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
