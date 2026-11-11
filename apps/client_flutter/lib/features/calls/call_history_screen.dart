import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/call_log.dart';
import '../../core/repositories/call_history_repository.dart';
import '../../core/repositories/conversation_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../discussions/widgets/call_dialog.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  String _selectedFilter = 'Tous'; // 'Tous', 'Manqués', 'Vidéos'

  void _triggerRedial(CallLog log) {
    final convRepo = context.read<ConversationRepository>();
    final conv = convRepo.getAllConversations().firstWhere(
          (c) => c.title.toLowerCase() == log.peerName.toLowerCase(),
          orElse: () => convRepo.getAllConversations().isNotEmpty
              ? convRepo.getAllConversations().first
              : throw Exception('No conversation'),
        );

    showDialog(
      context: context,
      builder: (ctx) => CallDialog(
        peerName: log.peerName,
        peerAvatar: log.peerAvatar,
        isVideo: log.isVideo,
        isPeerOnline: conv.isOnline,
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Effacer l\'historique', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Voulez-vous supprimer l\'ensemble de votre historique d\'appels locaux ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              context.read<CallHistoryRepository>().clearAll();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Historique des appels effacé')),
              );
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callRepo = context.watch<CallHistoryRepository>();
    final allLogs = callRepo.getAllLogs();

    final filteredLogs = _selectedFilter == 'Manqués'
        ? callRepo.getMissedLogs()
        : (_selectedFilter == 'Vidéos' ? callRepo.getVideoLogs() : allLogs);

    final missedCount = callRepo.getMissedLogs().length;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appels',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
            ),
            Text(
              '${allLogs.length} appel(s) sécurisé(s)',
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (allLogs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF64748B)),
              tooltip: 'Effacer l\'historique',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _filterPill('Tous', count: allLogs.length),
                const SizedBox(width: 8),
                _filterPill('Manqués', count: missedCount, isAlert: missedCount > 0),
                const SizedBox(width: 8),
                _filterPill('Vidéos', count: callRepo.getVideoLogs().length),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFDFE4ED)),

          // List of calls
          Expanded(
            child: filteredLogs.isEmpty
                ? AppEmptyState(
                    icon: Icons.phone_disabled_outlined,
                    title: _selectedFilter == 'Manqués'
                        ? 'Aucun appel manqué'
                        : 'Aucun appel dans l\'historique',
                    message:
                        'Vos appels vocaux et vidéo sécurisés s\'afficheront ici automatiquement.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filteredLogs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      return _buildCallTile(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(String title, {int count = 0, bool isAlert = false}) {
    final isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isAlert ? const Color(0xFFFEE2E2) : AppTheme.primarySoft)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isAlert ? const Color(0xFFEF4444) : AppTheme.primary)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? (isAlert ? const Color(0xFFDC2626) : AppTheme.primary)
                    : const Color(0xFF64748B),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isAlert ? const Color(0xFFDC2626) : AppTheme.primary)
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCallTile(CallLog log) {
    final isMissed = log.direction == CallDirection.missed;
    final isOutgoing = log.direction == CallDirection.outgoing;

    final IconData directionIcon;
    final Color directionColor;

    if (isMissed) {
      directionIcon = Icons.call_missed_rounded;
      directionColor = const Color(0xFFDC2626);
    } else if (isOutgoing) {
      directionIcon = Icons.call_made_rounded;
      directionColor = const Color(0xFF0043B8);
    } else {
      directionIcon = Icons.call_received_rounded;
      directionColor = const Color(0xFF10B981);
    }

    return Dismissible(
      key: ValueKey('log_${log.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        context.read<CallHistoryRepository>().deleteLog(log.id);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            AppAvatar(
              name: log.peerName,
              avatarUrl: log.peerAvatar,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.peerName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isMissed ? const Color(0xFFDC2626) : AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(directionIcon, size: 14, color: directionColor),
                      const SizedBox(width: 4),
                      Text(
                        '${log.timestamp} • ${log.duration}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                      ),
                      if (log.isVideo) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'VIDÉO',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDFE4ED)),
                ),
                child: Icon(
                  log.isVideo ? Icons.videocam : Icons.call,
                  size: 18,
                  color: const Color(0xFF0043B8),
                ),
              ),
              tooltip: 'Rappeler',
              onPressed: () => _triggerRedial(log),
            ),
          ],
        ),
      ),
    );
  }
}
