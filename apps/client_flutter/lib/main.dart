import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const MRixkApp());
}

class MRixkApp extends StatelessWidget {
  const MRixkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MRixk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  final List<Widget> _destinations = [
    const ConversationsScreen(),
    const LocalAIScreen(),
    const MomentsScreen(),
    const VaultScreen(),
    const DevicesSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      // Desktop / Tablet layout: NavigationRail on left, main view on right
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'MRixk',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.techBlue,
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: Text('Messages'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.psychology_outlined),
                  selectedIcon: Icon(Icons.psychology),
                  label: Text('MRixk AI'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.amp_stories_outlined),
                  selectedIcon: Icon(Icons.amp_stories),
                  label: Text('Moments'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.lock_outline),
                  selectedIcon: Icon(Icons.lock),
                  label: Text('Coffre'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.devices_outlined),
                  selectedIcon: Icon(Icons.devices),
                  label: Text('Appareils'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _destinations[_selectedIndex]),
          ],
        ),
      );
    }

    // Mobile layout: BottomNavigationBar with thumbnail thumbnail
    return Scaffold(
      body: _destinations[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'MRixk AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.amp_stories_outlined),
            selectedIcon: Icon(Icons.amp_stories),
            label: 'Moments',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline),
            selectedIcon: Icon(Icons.lock),
            label: 'Coffre',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Appareils',
          ),
        ],
      ),
    );
  }
}

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
            tooltip: 'Rechercher',
          ),
          IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: () {},
            tooltip: 'Nouvelle conversation',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            const Text(
              'Chiffrement de bout en bout actif',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vos messages et clés privées restent sur vos appareils autorisés.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class LocalAIScreen extends StatelessWidget {
  const LocalAIScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MRixk AI — Assistant Personnel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: const [
                    Icon(Icons.memory, color: AppTheme.techBlue, size: 36),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Moteur IA Strictement Local',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Zéro API distante • Espace cognitif M(u) isolé • Modèle quantifié',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Mémoire Personnelle Active', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.lightbulb_outline),
                    title: Text('Projet MRixk : Architecture cible'),
                    subtitle: Text('Source: Document interne • Confiance: 98% • Déclaré'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    leading: Icon(Icons.translate),
                    title: Text('Préférence de langue : Français'),
                    subtitle: Text('Source: Préférences utilisateur • Validé'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MomentsScreen extends StatelessWidget {
  const MomentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moments')),
      body: const Center(child: Text('Espace Moments et Statuts Privés')),
    );
  }
}

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coffre Personnel')),
      body: const Center(child: Text('Coffre-fort de fichiers chiffrés localement')),
    );
  }
}

class DevicesSettingsScreen extends StatelessWidget {
  const DevicesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des Appareils (Max 3)')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Appareils Connectés (Quota : 3 maximum)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.green),
              title: const Text('Téléphone Android (Cet appareil)'),
              subtitle: const Text('Session active • Clé Ed25519 vérifiée'),
              trailing: const Chip(label: Text('Actif', style: TextStyle(color: Colors.green))),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.laptop_windows),
              title: const Text('Ordinateur Windows'),
              subtitle: const Text('Dernière synchronisation il y a 2h'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Révoquer',
                onPressed: () {},
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.laptop_chromebook),
              title: const Text('Poste Linux'),
              subtitle: const Text('Dernière synchronisation hier'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Révoquer',
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
