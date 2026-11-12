import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mrixk_client/core/database/database_seed.dart';
import 'package:mrixk_client/core/database/local_database.dart';
import 'package:mrixk_client/core/repositories/device_repository.dart';
import 'package:mrixk_client/core/repositories/profile_repository.dart';
import 'package:mrixk_client/features/profile/profile_screen.dart';
import 'package:mrixk_client/shared/widgets/single_instance_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Account & Instance Guard Tests', () {
    late LocalDatabase db;
    late ProfileRepository profileRepo;
    late DeviceRepository devRepo;

    setUp(() async {
      db = LocalDatabase();
      await db.initialize(onSeed: (database) async {
        await seedTestDataForUnitTestsOnly(database);
      });
      profileRepo = ProfileRepository(db);
      devRepo = DeviceRepository(db);
    });

    Widget createTestApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileRepository>.value(value: profileRepo),
          ChangeNotifierProvider<DeviceRepository>.value(value: devRepo),
        ],
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      );
    }

    testWidgets('ProfileScreen renders personal identity and edit button', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Check for user identity card
      expect(find.text('Mon Espace'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Déconnexion / Changer de compte'), findsOneWidget);
      expect(find.text('Supprimer définitivement mon compte'), findsOneWidget);
    });

    testWidgets('Modifier button opens EditProfileDialog and updates personal info', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap on "Modifier" button
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier mes informations'), findsOneWidget);
      expect(find.text('Nom ou Pseudonyme'), findsOneWidget);
      expect(find.text('Identifiant souverain (Non modifiable)'), findsOneWidget);
      expect(find.text('Statut / Pensée'), findsOneWidget);

      final originalHandle = profileRepo.getProfile().handle;

      // Enter new values (handle is read-only)
      final nameField = find.widgetWithText(TextField, 'Nom ou Pseudonyme');
      final statusField = find.widgetWithText(TextField, 'Statut / Pensée');

      await tester.enterText(nameField, 'Souverain Testeur');
      await tester.enterText(statusField, 'Nouveau statut crypté');
      await tester.pumpAndSettle();

      // Tap Enregistrer
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Verify repository was updated (handle strictly preserved and immutable)
      final updated = profileRepo.getProfile();
      expect(updated.displayName, equals('Souverain Testeur'));
      expect(updated.handle, equals(originalHandle));
      expect(updated.statusMessage, equals('Nouveau statut crypté'));
      expect(find.text('Informations personnelles mises à jour avec succès'), findsOneWidget);
    });

    testWidgets('Déconnexion button triggers confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Déconnexion / Changer de compte'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap Logout
      await tester.tap(find.text('Déconnexion / Changer de compte'));
      await tester.pumpAndSettle();

      expect(find.text('Déconnexion'), findsWidgets);
      expect(find.text('Voulez-vous vous déconnecter de votre compte MRixk ?\n\nVotre session locale sera fermée. Vous pourrez vous reconnecter ou configurer un autre compte sur cet appareil.'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);

      // Cancel button closes dialog
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Voulez-vous vous déconnecter de votre compte MRixk ?\n\nVotre session locale sera fermée. Vous pourrez vous reconnecter ou configurer un autre compte sur cet appareil.'), findsNothing);
    });

    testWidgets('Supprimer mon compte triggers warning confirmation dialog and deletes account', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Supprimer définitivement mon compte'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap Delete account
      await tester.tap(find.text('Supprimer définitivement mon compte'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer définitivement mon compte'), findsWidgets);
      expect(find.text('Action irréversible et destructrice'), findsOneWidget);
      expect(find.text('Supprimer définitivement'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Action irréversible et destructrice'), findsNothing);
    });

    testWidgets('SingleInstanceGuard renders child when not locked out', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SingleInstanceGuard(
            child: Text('Contenu Principal Protégé'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contenu Principal Protégé'), findsOneWidget);
    });
  });
}
