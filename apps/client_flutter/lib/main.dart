import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/database/database_seed.dart';
import 'core/database/local_database.dart';
import 'core/repositories/assistant_repository.dart';
import 'core/repositories/call_history_repository.dart';
import 'core/repositories/contact_repository.dart';
import 'core/repositories/conversation_repository.dart';
import 'core/repositories/device_repository.dart';
import 'core/repositories/dws_media_repository.dart';
import 'core/repositories/group_note_repository.dart';
import 'core/repositories/message_repository.dart';
import 'core/repositories/moment_repository.dart';
import 'core/repositories/profile_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/splash_screen.dart';
import 'shared/widgets/single_instance_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize pure local database engine with clean production state and platform storage
  final localDb = LocalDatabase();
  await localDb.initialize(
    usePlatformStorage: true,
    onSeed: (db) async {
      await seedCleanProductionDatabase(db);
    },
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ContactRepository(localDb)),
        ChangeNotifierProvider(create: (_) => ConversationRepository(localDb)),
        ChangeNotifierProvider(create: (_) => MessageRepository(localDb)),
        ChangeNotifierProvider(create: (_) => MomentRepository(localDb)),
        ChangeNotifierProvider(create: (_) => DeviceRepository(localDb)),
        ChangeNotifierProvider(create: (_) => AssistantRepository(localDb)),
        ChangeNotifierProvider(create: (_) => CallHistoryRepository(localDb)),
        ChangeNotifierProvider(create: (_) => GroupNoteRepository(localDb)),
        ChangeNotifierProvider(create: (_) => DwsMediaRepository(localDb)),
        ChangeNotifierProvider(create: (_) => ProfileRepository(localDb)),
      ],
      child: const MRixkApp(),
    ),
  );
}

class MRixkApp extends StatelessWidget {
  const MRixkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileRepository>().getProfile();
    final isDark = profile.themeMode == 'Nuit';

    return MaterialApp(
      title: 'MRixk - Messagerie Privée & Souveraine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => SingleInstanceGuard(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
    );
  }
}
