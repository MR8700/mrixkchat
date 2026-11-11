import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/repositories/assistant_repository.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/memory_manager_dialog.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isListening = false;

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitPrompt([String? textOverride]) {
    final text = textOverride ?? _promptController.text.trim();
    if (text.isEmpty) return;

    context.read<AssistantRepository>().askAssistant(text);
    _promptController.clear();

    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openMemoryManager() {
    showDialog(
      context: context,
      builder: (ctx) => const MemoryManagerDialog(),
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.cleaning_services_rounded, color: Color(0xFF0043B8)),
            SizedBox(width: 8),
            Text('Effacer la conversation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Voulez-vous réinitialiser les échanges avec votre Assistant ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0043B8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              context.read<AssistantRepository>().clearAssistantMessages();
              Navigator.of(ctx).pop();
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assistantRepo = context.watch<AssistantRepository>();
    final messages = assistantRepo.getAssistantMessages();
    final activeMemoriesCount = assistantRepo.getActiveMemories().length;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0043B8), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0043B8).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assistant MRixk',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurface,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.statusGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'IA Souveraine active • 100% local',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.statusGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: 'Mémoire & Souvenirs ($activeMemoriesCount)',
            child: IconButton(
              icon: const Icon(Icons.memory_rounded, color: Color(0xFF0043B8)),
              onPressed: _openMemoryManager,
            ),
          ),
          if (messages.isNotEmpty)
            Tooltip(
              message: 'Effacer la conversation',
              child: IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF64748B)),
                onPressed: _confirmClearChat,
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Conversational stream taking full focus
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyWelcomeState(activeMemoriesCount)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _buildAssistantMessageBubble(msg);
                      },
                    ),
            ),

            // Quick suggestion prompt pills above input
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _quickPromptPill(
                      icon: Icons.forum_outlined,
                      label: 'Résumer les messages',
                      prompt: 'Résume mes échanges et messages récents',
                    ),
                    const SizedBox(width: 8),
                    _quickPromptPill(
                      icon: Icons.folder_shared_outlined,
                      label: 'Fichiers & Documents',
                      prompt: 'Quels sont les fichiers ou documents partagés ?',
                    ),
                    const SizedBox(width: 8),
                    _quickPromptPill(
                      icon: Icons.shield_outlined,
                      label: 'Sécurité de mes appareils',
                      prompt: 'Quel est l\'état de sécurité de mes appareils ?',
                    ),
                    const SizedBox(width: 8),
                    _quickPromptPill(
                      icon: Icons.contacts_outlined,
                      label: 'Mes contacts',
                      prompt: 'Quels sont mes contacts enregistrés ?',
                    ),
                    const SizedBox(width: 8),
                    _quickPromptPill(
                      icon: Icons.phone_in_talk_outlined,
                      label: 'Comment appeler ?',
                      prompt: 'Comment lancer un appel vocal ou vidéo sécurisé ?',
                    ),
                    const SizedBox(width: 8),
                    _quickPromptPill(
                      icon: Icons.edit_note_outlined,
                      label: 'Aide rédaction',
                      prompt: 'Aide-moi à rédiger un message bienveillant',
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // Bottom interactive chat input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _isListening = !_isListening);
                      if (_isListening) {
                        _promptController.text = 'Résume mes échanges et messages récents';
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isListening ? const Color(0xFFDC2626) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Icon(
                        Icons.mic,
                        color: _isListening ? Colors.white : const Color(0xFF0F172A),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? 'Écoute active...'
                            : 'Discutez avec votre Assistant...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _submitPrompt(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _submitPrompt(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0043B8), Color(0xFF245BDB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0043B8).withOpacity(0.35),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickPromptPill({
    required IconData icon,
    required String label,
    required String prompt,
  }) {
    return GestureDetector(
      onTap: () => _submitPrompt(prompt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF0043B8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWelcomeState(int activeMemoriesCount) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDFE4ED)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111C2C).withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0043B8), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0043B8).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Assistant Privé & Souverain',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Posez une question, demandez une synthèse ou discutez librement. Votre intelligence artificielle s\'exécute en toute confidentialité sur cet appareil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: Color(0xFF047857)),
                      const SizedBox(width: 6),
                      Text(
                        '$activeMemoriesCount informations retenues en mémoire protégée',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4 Action suggestion cards
          Row(
            children: [
              Expanded(
                child: _actionCard(
                  icon: Icons.forum_outlined,
                  iconColor: const Color(0xFF0043B8),
                  title: 'Résumer mes échanges',
                  subtitle: 'Synthèse claire',
                  onTap: () => _submitPrompt('Résume mes échanges et messages récents'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionCard(
                  icon: Icons.folder_shared_outlined,
                  iconColor: const Color(0xFF059669),
                  title: 'Rechercher un document',
                  subtitle: 'Fichiers & pièces',
                  onTap: () => _submitPrompt('Quels sont les fichiers ou documents partagés ?'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _actionCard(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFF4F46E5),
                  title: 'Sécurité & Appareils',
                  subtitle: 'État des terminaux',
                  onTap: () => _submitPrompt('Quel est l\'état de sécurité de mes appareils ?'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionCard(
                  icon: Icons.edit_note_outlined,
                  iconColor: const Color(0xFFD97706),
                  title: 'Rédiger un message',
                  subtitle: 'Aide bienveillante',
                  onTap: () => _submitPrompt('Aide-moi à rédiger un message bienveillant'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDFE4ED)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF111C2C).withOpacity(0.02),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppTheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantMessageBubble(AssistantMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0043B8), Color(0xFF245BDB)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0043B8).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                msg.text,
                style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.time,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, size: 12, color: Colors.white70),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0043B8), Color(0xFF2563EB)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0043B8).withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: const Color(0xFFDFE4ED)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF111C2C).withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.text,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.onSurface,
                        height: 1.45,
                      ),
                    ),
                    if (msg.sourceTitle != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.security, size: 14, color: Color(0xFF0043B8)),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg.sourceTitle!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.onSurface,
                                      ),
                                    ),
                                    if (msg.sourceSubtitle != null)
                                      Text(
                                        msg.sourceSubtitle!,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Text(
                                'Local',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0043B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          msg.confidenceText ?? 'Traitement souverain en 0.1s',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          msg.time,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
