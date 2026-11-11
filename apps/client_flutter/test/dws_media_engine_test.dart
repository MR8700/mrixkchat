import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/conversation.dart';
import 'package:mrixk_client/core/models/dws_media.dart';
import 'package:mrixk_client/core/repositories/call_history_repository.dart';
import 'package:mrixk_client/core/repositories/contact_repository.dart';
import 'package:mrixk_client/core/repositories/conversation_repository.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/dws_media_repository.dart';
import 'package:mrixk_client/core/repositories/group_note_repository.dart';
import 'package:mrixk_client/core/repositories/message_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/core/services/formula_engine.dart';
import 'package:mrixk_client/features/discussions/group_notepad_screen.dart';
import 'package:mrixk_client/features/discussions/widgets/group_note_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;
  late ConversationRepository convRepo;
  late GroupNoteRepository noteRepo;
  late MessageRepository messageRepo;
  late ProfileRepository profileRepo;
  late ContactRepository contactRepo;
  late DeviceRepository deviceRepo;
  late CallHistoryRepository callRepo;
  late DwsMediaRepository mediaRepo;

  setUp(() async {
    db = LocalDatabase();
    await db.initialize(usePlatformStorage: false);
    convRepo = ConversationRepository(db);
    noteRepo = GroupNoteRepository(db);
    messageRepo = MessageRepository(db);
    profileRepo = ProfileRepository(db);
    contactRepo = ContactRepository(db);
    deviceRepo = DeviceRepository(db);
    callRepo = CallHistoryRepository(db);
    mediaRepo = DwsMediaRepository(db);
  });

  group('MRixk DWS Multimedia Native Engine Suite', () {
    test('DwsMediaRepository initializes with sovereign seed assets and manages media lifecycle', () async {
      final initialMedia = mediaRepo.getMediaForGroup('conv_group_1');
      expect(initialMedia.length, greaterThanOrEqualTo(3));

      final schemaMedia = mediaRepo.getMediaBySlug('conv_group_1', 'schema_reseau');
      expect(schemaMedia, isNotNull);
      expect(schemaMedia!.type, DwsMediaType.image);
      expect(schemaMedia.caption, contains('Architecture générale du réseau'));

      final videoMedia = mediaRepo.getMediaBySlug('conv_group_1', 'experience');
      expect(videoMedia, isNotNull);
      expect(videoMedia!.type, DwsMediaType.video);
      expect(videoMedia.duration, '04:32');

      final audioMedia = mediaRepo.getMediaBySlug('conv_group_1', 'explication');
      expect(audioMedia, isNotNull);
      expect(audioMedia!.type, DwsMediaType.audio);
      expect(audioMedia.duration, '02:15');

      // Test registering a new sovereign media
      const newMedia = DwsMedia(
        id: 'media://group/asset_protocole_vpn',
        conversationId: 'conv_group_1',
        slug: 'protocole_vpn',
        type: DwsMediaType.pdf,
        source: 'data:application/pdf;base64,JVBERi0xLjc=',
        fileName: 'protocole_vpn.pdf',
        fileSize: '2.1 Mo',
        mimeType: 'application/pdf',
        caption: 'Spécification du tunnel VPN WireGuard post-quantique.',
        alt: 'Fiche technique protocole VPN',
        role: DwsMediaRole.annex,
        createdAt: '11 novembre 2026',
        createdBy: 'Richard MARE',
      );

      await mediaRepo.registerMedia(newMedia);
      final retrieved = mediaRepo.getMediaBySlug('conv_group_1', 'protocole_vpn');
      expect(retrieved, isNotNull);
      expect(retrieved!.fileName, 'protocole_vpn.pdf');

      final registry = mediaRepo.getAllGroupMediaRegistry('conv_group_1');
      expect(registry.containsKey('protocole_vpn'), isTrue);
      expect(registry.containsKey('schema_reseau'), isTrue);
    });

    test('Sovereign Local AI Assistant tools provide on-device enrichment without data leakage', () {
      final imgMedia = mediaRepo.getMediaBySlug('conv_group_1', 'schema_reseau')!;
      final autoCaption = mediaRepo.generateAutoCaption(imgMedia);
      expect(autoCaption, contains('schema reseau'));
      expect(autoCaption, contains('Figure technique'));

      final altText = mediaRepo.generateAltText(imgMedia);
      expect(altText, contains('Figure scientifique'));

      final ocrResult = mediaRepo.extractTextOcr(imgMedia);
      expect(ocrResult, contains('OCR Local MRixk'));
      expect(ocrResult, contains('Kyber-1024'));

      final audioMedia = mediaRepo.getMediaBySlug('conv_group_1', 'explication')!;
      final transcript = mediaRepo.transcribeAudio(audioMedia);
      expect(transcript, contains('Transcription Locale'));
      expect(transcript, contains('chiffrement de bout en bout'));
    });

    test('FormulaEngine autocomplete suggestions include native media insertion macros', () {
      final suggestions = FormulaEngine.suggestions;
      expect(suggestions.any((s) => s.template.contains('{image=')), isTrue);
      expect(suggestions.any((s) => s.template.contains('{video=')), isTrue);
      expect(suggestions.any((s) => s.template.contains('{audio=')), isTrue);
      expect(suggestions.any((s) => s.template.contains('{{media.?')), isTrue);
    });

    testWidgets('GroupNoteRenderer renders Method B {image=...} and Method C {{media.?...}} with dynamic figure numbering', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final registry = mediaRepo.getAllGroupMediaRegistry('conv_group_1');

      const docContent = '''
# Rapport d'Infrastructure Réseau

Voici l'architecture du réseau principal :
{image="schema_reseau.png" caption="Topologie générale des nœuds sécurisés" width=80%}

Démonstration de manipulation des équipements :
{{media.?experience}}

Et enfin les notes vocales associées :
{{media.?explication}}

Test de référence manquante :
{{media.?introuvable_ref}}
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupNoteRenderer(
              content: docContent,
              components: const {},
              mediaRegistry: registry,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Figure 1 and Figure 2 numbering
      expect(find.textContaining('Figure 1 — Topologie générale des nœuds sécurisés'), findsOneWidget);
      expect(find.textContaining('Figure 2 — Démonstration de configuration d\'un routeur sécurisé.'), findsOneWidget);

      // Check Video duration overlay & Play icon
      expect(find.text('MP4 · 04:32'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);

      // Check Audio player card & waveform
      expect(find.textContaining('MP3 · 02:15'), findsOneWidget);
      expect(find.textContaining('Explication audio de la formule de Gauss'), findsOneWidget);

      // Check Missing Media fallback error chip
      expect(find.textContaining('Média introuvable : {{media.?introuvable_ref}}'), findsOneWidget);
    });

    testWidgets('GroupNotepadScreen renders Word toolbar with Media button and opens insertion sheet', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final conv = Conversation(
        id: 'conv_group_1',
        title: 'Groupe R&D',
        peerAvatar: '',
        isGroup: true,
        groupMembersCount: 2,
        groupMembers: [
          GroupMember(id: 'user_richard', name: 'Richard MARE', role: 'creator'),
        ],
        lastMessage: 'Ouverture du document',
        lastMessageTime: '10:00',
      );
      await convRepo.createConversation(conv);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: convRepo),
            ChangeNotifierProvider.value(value: noteRepo),
            ChangeNotifierProvider.value(value: messageRepo),
            ChangeNotifierProvider.value(value: profileRepo),
            ChangeNotifierProvider.value(value: contactRepo),
            ChangeNotifierProvider.value(value: deviceRepo),
            ChangeNotifierProvider.value(value: callRepo),
            ChangeNotifierProvider.value(value: mediaRepo),
          ],
          child: MaterialApp(
            home: GroupNotepadScreen(conversation: conv),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Edit compartment
      final editButton = find.text('Éditer');
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Find Media button in contextual toolbar
      final mediaButton = find.widgetWithText(ElevatedButton, 'Média');
      expect(mediaButton, findsOneWidget);

      // Tap on Media button to open insertion modal sheet
      await tester.tap(mediaButton);
      await tester.pumpAndSettle();

      // Verify modal sheet options
      expect(find.text('Insérer un média natif DWS'), findsOneWidget);
      expect(find.text('Prendre une photo (Appareil photo)'), findsOneWidget);
      expect(find.text('Image depuis la galerie'), findsOneWidget);
      expect(find.text('Vidéo depuis les fichiers'), findsOneWidget);
      expect(find.text('Document PDF / Annexe'), findsOneWidget);
      expect(find.text('Média partagé dans la conversation'), findsOneWidget);
      expect(find.text('Bibliothèque médias du groupe'), findsOneWidget);
    });
  });
}
