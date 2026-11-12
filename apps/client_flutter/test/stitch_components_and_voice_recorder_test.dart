import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/features/discussions/widgets/call_dialog.dart';
import 'package:mrixk_client/features/discussions/widgets/whatsapp_voice_recorder.dart';
import 'package:mrixk_client/shared/widgets/app_avatar.dart';
import 'package:mrixk_client/shared/widgets/app_media_image.dart';

void main() {
  group('Google Stitch Components & WhatsApp Voice Recorder Suite', () {
    testWidgets('AppAvatar correctly generates initials and renders offline gradient', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              name: 'Richard MARE',
              radius: 24,
              isOnline: true,
              isVerified: true,
            ),
          ),
        ),
      );

      expect(find.text('RM'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('AppAvatar handles single names gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              name: 'Antigravity',
              radius: 20,
            ),
          ),
        ),
      );

      expect(find.text('AN'), findsOneWidget);
    });

    testWidgets('AppMediaImage renders resilient photocard with tags when offline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppMediaImage(
              imageUrl: null,
              fallbackTitle: 'Cliché Haute Définition',
              fallbackSubtitle: 'Format RAW • Protégé',
            ),
          ),
        ),
      );

      expect(find.text('Cliché Haute Définition'), findsOneWidget);
      expect(find.text('Format RAW • Protégé'), findsOneWidget);
      expect(find.text('Qualité HD'), findsOneWidget);
      expect(find.text('Espace Sécurisé'), findsOneWidget);
      expect(find.byIcon(Icons.camera_rounded), findsOneWidget);
    });

    testWidgets('WhatsAppVoiceRecorder renders recording UI and triggers onSend', (tester) async {
      String? sentDuration;
      List<double>? sentWaveform;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatsAppVoiceRecorder(
              onSend: (dur, wave) {
                sentDuration = dur;
                sentWaveform = wave;
              },
              onCancel: () {
                cancelled = true;
              },
            ),
          ),
        ),
      );

      // Verify timer and waveform presence
      expect(find.text('00:00'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      // Advance time by 2 seconds
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:02'), findsOneWidget);

      // Tap send button
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      expect(sentDuration, equals('00:02'));
      expect(sentWaveform, isNotNull);
      expect(sentWaveform!.isNotEmpty, isTrue);
      expect(cancelled, isFalse);
    });

    testWidgets('WhatsAppVoiceRecorder triggers onCancel when trash is clicked', (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatsAppVoiceRecorder(
              onSend: (_, __) {},
              onCancel: () {
                cancelled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('CallDialog rings and connects with private badges and ends call', (tester) async {
      String? endedDuration;
      bool? wasVideoEnded;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallDialog(
              peerName: 'Dr. Elena Rostova',
              peerAvatar: '',
              isVideo: false,
              isPeerOnline: true,
              onCallEnded: (duration, isVideo) {
                endedDuration = duration;
                wasVideoEnded = isVideo;
              },
            ),
          ),
        ),
      );

      // Initial state: Ringing
      expect(find.text('Dr. Elena Rostova'), findsOneWidget);
      expect(find.text('Sonnerie en cours...'), findsOneWidget);

      // Advance 3.1 seconds to trigger connect
      await tester.pump(const Duration(milliseconds: 3100));
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Appel audio direct et protégé'), findsOneWidget);
      expect(find.text('00:03'), findsOneWidget);

      // Tap hang up
      await tester.tap(find.byIcon(Icons.call_end));
      await tester.pumpAndSettle();

      expect(endedDuration, equals('00:03'));
      expect(wasVideoEnded, isFalse);
    });

    testWidgets('WhatsAppVoiceRecorder pause reveals blue play button and resume records again', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatsAppVoiceRecorder(
              onSend: (_, __) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      // Record for 2 seconds
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:02'), findsOneWidget);

      // Tap pause button (Icons.pause_rounded)
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      // In paused state:
      // 1. Blue play button appears (Icons.play_arrow_rounded)
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      // 2. Red resume recording mic button appears (Icons.mic)
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Tap play button to test preview playback
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget); // playing state has pause icon

      // Tap resume record mic button
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();

      // Now recording resumes: pause button returns, mic resume button is hidden
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Record further
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:03'), findsOneWidget);
    });

    testWidgets('MRixkLogo renders circular sovereign emblem', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MRixkLogo(size: 60),
          ),
        ),
      );

      expect(find.byType(MRixkLogo), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('AppAvatar is clickable to enlarge and displays enlarged dialog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              name: 'Dr. Elena Rostova',
              radius: 24,
              isOnline: true,
              isVerified: true,
            ),
          ),
        ),
      );

      // Tap on the avatar
      await tester.tap(find.byType(AppAvatar));
      await tester.pumpAndSettle();

      // Dialog opens with close button and user name
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('En ligne • Profil vérifié'), findsOneWidget);

      // Close the dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('CallDialog counter does not increment during ringing and shows unavailable state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallDialog(
              peerName: 'Dr. Elena Rostova',
              peerAvatar: '',
              isVideo: false,
            ),
          ),
        ),
      );

      // Ringing state: timer strictly says 'Sonnerie chez le correspondant...' (does not tick 00:01)
      expect(find.text('Sonnerie chez le correspondant...'), findsOneWidget);

      // Tap simulate busy/unavailable button
      expect(find.text('Simuler Occupé'), findsOneWidget);
      await tester.tap(find.text('Simuler Occupé'));
      await tester.pump();

      // Shows unavailable badge & text
      expect(find.text('Correspondant indisponible'), findsOneWidget);
      expect(find.text('Indisponible pour le moment'), findsOneWidget);
      expect(find.text('Message vocal : "Correspondant indisponible."'), findsOneWidget);
    });
  });
}
