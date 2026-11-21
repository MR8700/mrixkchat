import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_client.dart';
import '../../core/services/webrtc_call_service.dart';
import '../../core/repositories/contact_repository.dart';
import '../../core/repositories/conversation_repository.dart';
import '../../core/repositories/message_repository.dart';
import '../../core/repositories/profile_repository.dart';
import '../../core/services/account_reconciliation_service.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/discussions/widgets/call_dialog.dart';
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
  bool _connectingRealtime = false;
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  StreamSubscription<IncomingRtcCall>? _incomingCallSubscription;
  StreamSubscription<String>? _incomingEndedSubscription;
  String? _showingIncomingCallId;

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
    _realtimeSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    _incomingEndedSubscription?.cancel();
    WebRtcCallService.instance.unbindSignals();
    WebSocketClient().disconnect();
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
    await _ensureRealtime(profileRepo);
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

  Future<void> _ensureRealtime(ProfileRepository profileRepo) async {
    final api = ApiClient();
    final profile = profileRepo.getProfile();
    final saved = profileRepo.getRealtimeSessionToken();
    if (_connectingRealtime) return;
    if ((profile.recoveryCode == null || profile.recoveryCode!.isEmpty) &&
        (api.sessionToken == null || api.sessionToken!.isEmpty) &&
        (saved == null || saved.isEmpty)) {
      return;
    }
    _connectingRealtime = true;
    try {
      final deviceKey = await profileRepo.getOrCreateRealtimeDeviceKey();
      var token = api.sessionToken;
      if ((token == null || token.isEmpty) && saved != null && saved.isNotEmpty) {
        api.setSessionToken(saved);
        token = saved;
      }

      final needsRenewal = profileRepo.realtimeSessionNeedsRenewal;
      if (token != null &&
          token.isNotEmpty &&
          (needsRenewal || !WebSocketClient().isConnected)) {
        final valid = await api.validateRealtimeSession();
        if (valid == false) {
          api.clearSessionToken();
          token = null;
        } else if (valid == true && needsRenewal) {
          // Refresh every 20 days, before the server's 30-day session expiry.
          // The stable key reuses this device record instead of consuming quota.
          final renewed = await api.linkRealtimeDeviceKey(deviceKey);
          if (renewed != null) {
            token = renewed;
            await profileRepo.saveRealtimeSessionToken(renewed);
          }
        }
      }

      if (token == null || token.isEmpty) {
        if (profile.recoveryCode == null || profile.recoveryCode!.isEmpty) return;
        final platform = kIsWeb
            ? 'Web'
            : switch (defaultTargetPlatform) {
                TargetPlatform.android => 'Android',
                TargetPlatform.iOS => 'iOS',
                TargetPlatform.windows => 'Windows',
                _ => 'Linux',
              };
        token = await api.authorizeRecoveryDevice(
          userId: profile.id,
          recoveryCode: profile.recoveryCode!,
          deviceName: kIsWeb ? 'MRixk Web' : 'MRixk $platform',
          platform: platform,
          clientDeviceKey: deviceKey,
        );
        if (token != null) await profileRepo.saveRealtimeSessionToken(token);
      }
      if (token == null || token.isEmpty) return;

      WebRtcCallService.instance.bindSignals(WebSocketClient().events);
      _incomingCallSubscription ??=
          WebRtcCallService.instance.incomingCalls.listen((invitation) {
        if (!mounted) return;
        if (WebRtcCallService.instance.isActive) {
          unawaited(
              WebRtcCallService.instance.rejectIncoming(invitation.callId));
          return;
        }
        _showingIncomingCallId = invitation.callId;
        showResponsiveDialog<void>(
          context: context,
          builder: (_) {
            final peer = context
                .read<ContactRepository>()
                .getContactById(invitation.callerId);
            return CallDialog(
              peerName: peer?.name ?? invitation.callerId,
              peerAvatar: peer?.avatarUrl ?? '',
              peerUserId: invitation.callerId,
              isVideo: invitation.isVideo,
              incomingCall: invitation,
            );
          },
        );
      });
      _incomingEndedSubscription ??=
          WebRtcCallService.instance.incomingEnded.listen((id) {
        if (!mounted || _showingIncomingCallId != id) return;
        _showingIncomingCallId = null;
        if (WebRtcCallService.instance.callId != id &&
            widget.navigatorKey.currentState?.canPop() == true) {
          widget.navigatorKey.currentState?.pop();
        }
      });
      _realtimeSubscription ??= WebSocketClient().events.listen((event) {
        final type = event['type'];
        if (type == '_CONNECTED' ||
            type == 'MESSAGE_REQUEST') {
          // Requests are stored durably by the server, so syncing here also
          // recovers events missed during a disconnect. Updating the local DB
          // notifies repositories and refreshes conversation/request UI.
          unawaited(context
              .read<MessageRepository>()
              .syncIncomingMessageRequests()
              .catchError((_) {}));
        } else if (type == 'MESSAGE_REQUEST_UPDATED' &&
            event['payload'] is Map) {
          unawaited(context
              .read<MessageRepository>()
              .handleMessageRequestUpdated(
                  Map<String, dynamic>.from(event['payload'] as Map))
              .catchError((_) {}));
        }
      });
      await WebSocketClient().connect(token);
    } finally {
      _connectingRealtime = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
