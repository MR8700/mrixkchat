import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/conversation.dart';
import '../../core/repositories/conversation_repository.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../features/assistant/assistant_screen.dart';
import '../../features/contacts/contacts_screen.dart';
import '../../features/discussions/conversation_detail_screen.dart';
import '../../features/discussions/discussions_screen.dart';
import '../../features/moments/moments_screen.dart';
import '../../features/profile/profile_screen.dart';
import 'app_avatar.dart';
import 'floating_bottom_nav.dart';

class ResponsiveScaffold extends StatefulWidget {
  const ResponsiveScaffold({super.key});

  @override
  State<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends State<ResponsiveScaffold> {
  int _selectedIndex = 0;
  Conversation? _selectedDesktopConversation;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1200;
    final isTablet = width >= 768 && width < 1200;
    final convRepo = context.watch<ConversationRepository>();
    final allConvs = convRepo.getAllConversations();
    final unreadTotal = allConvs.where((c) => c.unreadCount > 0).length;

    // Default select first non-archived conversation for desktop/tablet if null
    final nonArchived = allConvs.where((c) => !c.isArchived).toList();
    if ((isDesktop || isTablet) && _selectedDesktopConversation == null && nonArchived.isNotEmpty) {
      _selectedDesktopConversation = nonArchived.first;
    }

    // Keep active conversation updated, or cleanly deselect if it was archived/deleted
    if (_selectedDesktopConversation != null) {
      final fresh = convRepo.getConversationById(_selectedDesktopConversation!.id);
      if (fresh == null || (fresh.isArchived && !_selectedDesktopConversation!.isArchived)) {
        _selectedDesktopConversation = null;
      } else {
        _selectedDesktopConversation = fresh;
      }
    }

    if (isDesktop) {
      return _buildDesktopLayout(context, unreadTotal);
    } else if (isTablet) {
      return _buildTabletLayout(context, unreadTotal);
    } else {
      return _buildMobileLayout(context, unreadTotal);
    }
  }

  // --- MOBILE LAYOUT (< 768px) ---
  Widget _buildMobileLayout(BuildContext context, int unreadTotal) {
    final screens = [
      DiscussionsScreen(onNavigateTab: (idx) => setState(() => _selectedIndex = idx)),
      const MomentsScreen(),
      const ContactsScreen(),
      const AssistantScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingBottomNav(
              selectedIndex: _selectedIndex,
              unreadCount: unreadTotal,
              onItemSelected: (index) {
                setState(() => _selectedIndex = index);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- TABLET LAYOUT (768px - 1199px) ---
  Widget _buildTabletLayout(BuildContext context, int unreadTotal) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // 72px Navigation Rail
          NavigationRail(
            backgroundColor: theme.colorScheme.surface,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: MRixkLogo(size: 40),
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.chat_bubble_outline),
                selectedIcon: const Icon(Icons.chat_bubble),
                label: const Text('Discussions', style: TextStyle(fontSize: 10.5)),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.slow_motion_video),
                selectedIcon: const Icon(Icons.slow_motion_video),
                label: const Text('Moments', style: TextStyle(fontSize: 10.5)),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.contacts_outlined),
                selectedIcon: const Icon(Icons.contacts),
                label: const Text('Contacts', style: TextStyle(fontSize: 10.5)),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.auto_awesome_outlined),
                selectedIcon: const Icon(Icons.auto_awesome),
                label: const Text('Assistant', style: TextStyle(fontSize: 10.5)),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.account_circle_outlined),
                selectedIcon: const Icon(Icons.account_circle),
                label: const Text('Profil', style: TextStyle(fontSize: 10.5)),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFDFE4ED)),

          // 2-pane split if discussions is selected
          if (_selectedIndex == 0) ...[
            SizedBox(
              width: 360,
              child: DiscussionsScreen(
                onSelectConversationDesktop: (conv) {
                  setState(() => _selectedDesktopConversation = conv);
                },
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFCBD5E1)),
            Expanded(
              child: _selectedDesktopConversation != null
                  ? ConversationDetailScreen(
                      conversation: _selectedDesktopConversation!,
                      onCloseDesktop: () => setState(() => _selectedDesktopConversation = null),
                    )
                  : const Center(
                      child: Text(
                        'Sélectionnez une discussion pour afficher l\'échange sécurisé',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ] else ...[
            Expanded(
              child: [
                const SizedBox(),
                const MomentsScreen(),
                const ContactsScreen(),
                const AssistantScreen(),
                const ProfileScreen(),
              ][_selectedIndex],
            ),
          ],
        ],
      ),
    );
  }

  // --- DESKTOP 3-PANE LAYOUT (>= 1200px) ---
  Widget _buildDesktopLayout(BuildContext context, int unreadTotal) {
    final profile = context.watch<ProfileRepository>().getProfile();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Pane 1: Master Navigation / Verified Nodes (260px fixed)
          Container(
            width: 260,
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MRixk Brand
                Row(
                  children: [
                    const MRixkLogo(size: 42),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'MRixk Desktop',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          'Nœud souverain vérifié',
                          style: TextStyle(fontSize: 11, color: AppTheme.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Navigation items
                _desktopNavItem(0, Icons.chat_bubble, 'Discussions', unreadTotal),
                _desktopNavItem(1, Icons.slow_motion_video, 'Moments'),
                _desktopNavItem(2, Icons.contacts, 'Contacts'),
                _desktopNavItem(3, Icons.auto_awesome, 'Assistant'),
                _desktopNavItem(4, Icons.account_circle, 'Profil'),

                const Spacer(),

                // Security posture badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWarm,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDFE4ED)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.statusGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cryptographie Active',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              profile.displayName,
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFCBD5E1)),

          // Pane 2: Middle Stream (fluid 450px)
          SizedBox(
            width: 450,
            child: _selectedIndex == 0
                ? DiscussionsScreen(
                    onSelectConversationDesktop: (conv) {
                      setState(() => _selectedDesktopConversation = conv);
                    },
                  )
                : [
                    const SizedBox(),
                    const MomentsScreen(),
                    const ContactsScreen(),
                    const AssistantScreen(),
                    const ProfileScreen(),
                  ][_selectedIndex],
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFCBD5E1)),

          // Pane 3: Right Pane: Active Detail or Sovereign Inspector
          Expanded(
            child: _selectedDesktopConversation != null
                ? ConversationDetailScreen(
                    conversation: _selectedDesktopConversation!,
                    onCloseDesktop: () => setState(() => _selectedDesktopConversation = null),
                  )
                : Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.shield_outlined, size: 48, color: AppTheme.primary),
                          SizedBox(height: 12),
                          Text(
                            'Sélectionnez une discussion pour afficher l\'échange sécurisé',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurfaceVariant,
                            ),
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

  Widget _desktopNavItem(int index, IconData icon, String label, [int? badge]) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primary : AppTheme.onSurface,
                ),
              ),
            ),
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
