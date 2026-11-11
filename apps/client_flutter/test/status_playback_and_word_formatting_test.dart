import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/models/moment.dart';
import 'package:mrixk_client/core/repositories/moment_repository.dart';
import 'package:mrixk_client/features/discussions/controllers/word_rich_text_controller.dart';
import 'package:mrixk_client/features/discussions/widgets/audio_player_widget.dart';
import 'package:mrixk_client/features/moments/widgets/moment_story_viewer_dialog.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;

  setUp(() async {
    db = LocalDatabase();
    if (!db.isInitialized) {
      await db.initialize();
    }
  });

  group('Lectures Audio, Vidéo, Vocaux & Pause dans les Status / Moments', () {
    testWidgets('MomentStoryViewerDialog dispose d\'un bouton Pause/Reprendre interactif et badge "En pause"', (tester) async {
      final moment = Moment(
        id: 'moment-voice-test',
        authorId: 'USR-TEST',
        authorName: 'Richard Test',
        authorAvatar: '',
        timeAgo: 'Il y a 10 min',
        caption: 'Enregistrement vocal important',
        type: MomentType.voice,
        voiceDuration: '0:45',
        mediaUrl: 'https://example.com/voice.m4a',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MomentRepository(db)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (_) => MomentStoryViewerDialog(initialMoment: moment),
                    );
                  },
                  child: const Text('Ouvrir Statut'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir Statut'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // AudioPlayerWidget and duration are rendered
      expect(find.byType(AudioPlayerWidget), findsOneWidget);
      expect(find.text('Durée : 0:45'), findsOneWidget);

      // Verify Pause button is in header
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('En pause'), findsNothing);

      // Tap Pause
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      // Now paused: shows Play arrow and "En pause" badge
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      expect(find.text('En pause'), findsOneWidget);

      // Tap Play arrow to resume
      await tester.tap(find.byTooltip('Reprendre la lecture'));
      await tester.pump();
      expect(find.text('En pause'), findsNothing);
    });

    testWidgets('AudioPlayerWidget déclenche onPlayStateChanged lors du démarrage et de l\'arrêt', (tester) async {
      bool? isPlayingNotified;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              duration: '0:10',
              onPlayStateChanged: (playing) {
                isPlayingNotified = playing;
              },
            ),
          ),
        ),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Tap Play
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(isPlayingNotified, isTrue);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Tap Pause
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      expect(isPlayingNotified, isFalse);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('Moment de type vidéo affiche le bouton interactif "Regarder la vidéo"', (tester) async {
      final moment = Moment(
        id: 'moment-vid-test',
        authorId: 'USR-TEST',
        authorName: 'Richard Test',
        authorAvatar: '',
        timeAgo: 'Il y a 20 min',
        caption: 'Vidéo de test MRixk',
        type: MomentType.video,
        mediaUrl: 'https://example.com/test.mp4',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MomentRepository(db)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (_) => MomentStoryViewerDialog(initialMoment: moment),
                    );
                  },
                  child: const Text('Ouvrir Vidéo'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir Vidéo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Regarder la vidéo'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
    });
  });

  group('Word Engine — Typographie sans écrasement de texte & Rendu Microsoft Word', () {
    testWidgets('WordRichTextController opère sur tampon propre sans aucune balise masquée ou écrasement', (tester) async {
      const text = '<font color="#059669">texte</font> [align=left] **gras** <u>souligné</u>';
      final controller = WordRichTextController(text: text);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                final span = controller.buildTextSpan(context: ctx, withComposing: false);
                return Text.rich(span);
              },
            ),
          ),
        ),
      );

      final span = controller.buildTextSpan(
        context: tester.element(find.byType(Scaffold)),
        withComposing: false,
      );

      // Verify there are ZERO transparent or 0.001 size tags in the rendered spans
      bool hasInvisibleSpans = false;
      span.visitChildren((child) {
        if (child is TextSpan && child.style?.color == Colors.transparent) {
          hasInvisibleSpans = true;
        }
        return true;
      });
      expect(hasInvisibleSpans, isFalse,
          reason: 'L\'espace spécialisé Word opère sur du texte propre : aucune balise masquée ne pollue l\'éditeur.');

      // Check clean text and rendered formatting
      expect(controller.text, equals('texte gras souligné'));
      expect(controller.toMarkdown(), contains('**gras**'));
      expect(controller.toMarkdown(), contains('<u>souligné</u>'));
    });
  });
}
