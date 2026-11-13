import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:mrixk_client/core/database/database_seed.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/repositories/assistant_repository.dart';
import 'package:mrixk_client/core/repositories/call_history_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/dws_media_repository.dart';
import 'package:mrixk_client/core/repositories/group_note_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/moment_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/theme/app_theme.dart';
import 'package:mrixk_client/features/assistant/assistant_screen.dart';
import 'package:mrixk_client/features/contacts/contacts_screen.dart';
import 'package:mrixk_client/features/contacts/widgets/add_contact_dialog.dart';
import 'package:mrixk_client/features/calls/call_history_screen.dart';
import 'package:mrixk_client/features/discussions/conversation_detail_screen.dart';
import 'package:mrixk_client/features/discussions/conversation_info_screen.dart';
import 'package:mrixk_client/features/discussions/group_notepad_screen.dart';
import 'package:mrixk_client/features/discussions/discussions_screen.dart';
import 'package:mrixk_client/features/moments/moments_screen.dart';
import 'package:mrixk_client/features/onboarding/identity_setup_screen.dart';
import 'package:mrixk_client/features/profile/profile_screen.dart';
import 'package:mrixk_client/shared/widgets/responsive_scaffold.dart';
import 'package:mrixk_client/shared/responsive/responsive.dart';

/// Every main screen and the add-contact modal must render without layout overflow
/// on phones (small / large), tablets and desktop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sizes = <String, Size>{
    'phone 360x640': Size(360, 640),
    'phone 412x915': Size(412, 915),
    'tablet 768x1024': Size(768, 1024),
    'desktop 1280x800': Size(1280, 800),
  };

  late LocalDatabase db;
  final emptyServer = MockClient((_) async => http.Response(
        jsonEncode({'users': [], 'count': 0}),
        200,
        headers: {'content-type': 'application/json'},
      ));

  setUp(() async {
    db = LocalDatabase();
    await db.initialize(onSeed: (d) async => seedTestDataForUnitTestsOnly(d));
  });

  Widget app(Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ContactRepository(db)),
          ChangeNotifierProvider(create: (_) => ConversationRepository(db)),
          ChangeNotifierProvider(create: (_) => MessageRepository(db)),
          ChangeNotifierProvider(create: (_) => MomentRepository(db)),
          ChangeNotifierProvider(create: (_) => DeviceRepository(db)),
          ChangeNotifierProvider(create: (_) => AssistantRepository(db)),
          ChangeNotifierProvider(create: (_) => CallHistoryRepository(db)),
          ChangeNotifierProvider(create: (_) => GroupNoteRepository(db)),
          ChangeNotifierProvider(create: (_) => DwsMediaRepository(db)),
          ChangeNotifierProvider(create: (_) => ProfileRepository(db)),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: home),
      );

  final screens = <String, Widget Function()>{
    'Discussions': () => DiscussionsScreen(onNavigateTab: (_) {}),
    'Moments': () => const MomentsScreen(),
    'Contacts': () => const ContactsScreen(),
    'Assistant': () => const AssistantScreen(),
    'Profil': () => const ProfileScreen(),
    'Identité (onboarding)': () => const IdentitySetupScreen(),
    'ResponsiveScaffold': () => const ResponsiveScaffold(),
    'Appels': () => const CallHistoryScreen(),
    'Conversation': () => ConversationDetailScreen(
          conversation: ConversationRepository(db).getAllConversations().first,
        ),
    'Informations de conversation': () => ConversationInfoScreen(
          conversation: ConversationRepository(db).getAllConversations().first,
        ),
    'Bloc-notes de groupe': () => GroupNotepadScreen(
          conversation: ConversationRepository(db)
              .getAllConversations()
              .firstWhere((c) => c.isGroup),
        ),
  };

  for (final sizeEntry in sizes.entries) {
    for (final screenEntry in screens.entries) {
      testWidgets('${screenEntry.key} @ ${sizeEntry.key} sans débordement',
          (tester) async {
        tester.view.physicalSize = sizeEntry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await http.runWithClient(() async {
          await tester.pumpWidget(app(screenEntry.value()));
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, () => emptyServer);
      });
    }

    testWidgets(
        'AddContactDialog @ ${sizeEntry.key} (clavier ouvert) sans débordement',
        (tester) async {
      tester.view.physicalSize = sizeEntry.value;
      tester.view.devicePixelRatio = 1.0;
      // Simulate on-screen keyboard taking ~40% of the height
      tester.view.viewInsets =
          FakeViewPadding(bottom: sizeEntry.value.height * 0.4);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(app(Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAdaptiveModal(ctx,
                    builder: (_) => const AddContactDialog()),
                child: const Text('open'),
              ),
            ),
          ),
        )));
        await tester.tap(find.text('open'));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Ajouter un contact'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }, () => emptyServer);
    });

    testWidgets('AdaptiveAlertDialog @ ${sizeEntry.key} sans débordement',
        (tester) async {
      tester.view.physicalSize = sizeEntry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(app(Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showResponsiveDialog<void>(
                context: ctx,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Dialogue adaptative'),
                  content: const Text(
                      'Contenu de contrôle pour les quatre tailles d’écran.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Fermer'))
                  ],
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Dialogue adaptative'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
