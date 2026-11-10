import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrixk_client/features/viewers/image_viewer_screen.dart';
import 'package:mrixk_client/features/viewers/video_player_screen.dart';
import 'package:mrixk_client/features/viewers/document_viewer_screen.dart';
import 'package:mrixk_client/features/media_vault/media_vault_screen.dart';
import 'package:mrixk_client/features/security/security_verification_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MRixk File Viewers & Media Vault Suite', () {
    testWidgets('ImageViewerScreen renders with download icon, title and interactive viewer',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImageViewerScreen(
            imageUri: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800',
            title: 'Sophie Valade',
            subtitle: 'Reçu à 10:43 • E2EE',
          ),
        ),
      );

      // Verify title & subtitle
      expect(find.text('Sophie Valade'), findsOneWidget);
      expect(find.text('Reçu à 10:43 • E2EE'), findsOneWidget);

      // Verify interactive zoom & download icon
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.file_download), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);

      // Tap download button -> SnackBar triggers
      await tester.tap(find.byIcon(Icons.file_download));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.textContaining('/MRixk/Media/Images/'), findsOneWidget);
    });

    testWidgets('VideoPlayerScreen renders with video controls, download icon, and play toggle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayerScreen(
            videoUri: 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
            title: 'Démonstration Flux E2EE',
            duration: '1:45',
          ),
        ),
      );

      // Verify header and duration
      expect(find.text('Démonstration Flux E2EE'), findsOneWidget);
      expect(find.textContaining('01:45'), findsOneWidget);

      // Verify download button
      expect(find.byIcon(Icons.file_download), findsOneWidget);

      // Tap play/pause button
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_circle_fill));
      await tester.pump();
      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);

      // Tap download button -> SnackBar triggers
      await tester.tap(find.byIcon(Icons.file_download));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.textContaining('/MRixk/Media/Videos/'), findsOneWidget);
    });

    testWidgets('DocumentViewerScreen renders with multi-page viewer, cryptographic signature badge, and download icon',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DocumentViewerScreen(
            fileName: 'Architecture_MRixk_V2.pdf',
            fileSize: '3.4 Mo',
          ),
        ),
      );

      // Verify title and Ed25519 signature badge
      expect(find.text('Architecture_MRixk_V2.pdf'), findsAtLeastNWidgets(1));
      expect(find.textContaining('signature Ed25519'), findsOneWidget);

      // Verify page navigation controls
      expect(find.text('Page 1 sur 3'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 sur 3'), findsOneWidget);

      // Verify download button
      expect(find.byIcon(Icons.file_download), findsOneWidget);
      await tester.tap(find.byIcon(Icons.file_download));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.textContaining('/MRixk/Documents/'), findsOneWidget);
    });

    testWidgets('MediaVaultScreen renders 4 tabs, search bar, and empty states',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaVaultScreen(),
        ),
      );

      // Verify App Bar & 4 Tabs
      expect(find.text('Dossier Médias & Coffre'), findsOneWidget);
      expect(find.text('Médias (Photos/Vidéos)'), findsOneWidget);
      expect(find.text('Documents (PDF/DOC)'), findsOneWidget);
      expect(find.text('Audios'), findsOneWidget);
      expect(find.text('Coffre-fort Personnel'), findsOneWidget);

      // Switch to Documents Tab
      await tester.tap(find.text('Documents (PDF/DOC)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Aucun document'), findsWidgets);

      // Switch to Audios Tab
      await tester.tap(find.text('Audios'));
      await tester.pumpAndSettle();
      expect(find.textContaining('fichier audio'), findsWidgets);

      // Switch to Coffre-fort Tab
      await tester.tap(find.text('Coffre-fort Personnel'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Coffre-fort'), findsWidgets);
    });

    testWidgets('SecurityVerificationScreen renders 60-digit safety numbers, QR code, and verify toggle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SecurityVerificationScreen(
            peerName: 'Sophie Valade',
            peerAvatar: '',
            isVerified: false,
          ),
        ),
      );

      // Verify title, peer name, and safety number sections
      expect(find.text('Numéro de sécurité'), findsOneWidget);
      expect(find.textContaining('Sophie Valade'), findsWidgets);
      expect(find.text('Empreinte QR'), findsOneWidget);

      // Verify switch to mark as verified
      expect(find.text('Marquer ce contact comme vérifié'), findsOneWidget);
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(find.textContaining('Contact marqué comme vérifié'), findsOneWidget);
    });
  });
}
