import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/contact_repository.dart';
import '../../core/repositories/conversation_repository.dart';
import '../../core/repositories/message_repository.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/services/account_reconciliation_service.dart';
import '../../features/onboarding/splash_screen.dart';
import '../responsive/responsive.dart';

/// Wakes the server at startup and keeps local state coherent with it (deleted accounts,
/// profile changes) on launch, periodically, and when the app returns to the foreground.
class ReconciliationRunner extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  const ReconciliationRunner(
      {super.key, required this.child, required this.navigatorKey});

  @override
  State<ReconciliationRunner> createState() => _ReconciliationRunnerState();
}

class _ReconciliationRunnerState extends State<ReconciliationRunner>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _restorePromptShown = false;
  bool _syncingRequests = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiClient().warmUp().then((_) => _reconcile());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _reconcile());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reconcile();
  }

  Future<void> _reconcile() async {
    if (!mounted) return;
    final profileRepo = context.read<ProfileRepository>();
    if (!profileRepo.hasConfiguredIdentity) return;
    if (!_syncingRequests) {
      _syncingRequests = true;
      try {
        await context.read<MessageRepository>().syncIncomingMessageRequests();
      } catch (_) {
        // Keep already cached requests visible when the server is temporarily unavailable.
      } finally {
        _syncingRequests = false;
      }
    }
    final result = await AccountReconciliationService.run(
      contacts: context.read<ContactRepository>(),
      conversations: context.read<ConversationRepository>(),
      messages: context.read<MessageRepository>(),
      profile: profileRepo,
    );
    if (!mounted) return;
    if (result.selfDeleted) {
      await profileRepo.wipeLocalAccount();
      widget.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (_) => false,
      );
      return;
    }
    if (result.selfMissing && !_restorePromptShown) {
      _restorePromptShown = true;
      final shouldRestore = await showResponsiveDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Compte absent du serveur'),
          content: const Text(
            'Le serveur ne connaît plus ce compte. Voulez-vous le restaurer avec son même identifiant, son @handle et son code de secours local ?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Plus tard')),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Restaurer')),
          ],
        ),
      );
      if (shouldRestore == true && mounted) {
        try {
          await profileRepo.restoreExistingIdentity();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compte restauré sur le serveur.')),
          );
        } catch (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restauration impossible : $error')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
