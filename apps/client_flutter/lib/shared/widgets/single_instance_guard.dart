import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/local_database.dart';
import '../../core/database/platform_storage/platform_storage.dart';
import '../../core/theme/app_theme.dart';

class SingleInstanceGuard extends StatefulWidget {
  final Widget child;

  const SingleInstanceGuard({
    super.key,
    required this.child,
  });

  @override
  State<SingleInstanceGuard> createState() => _SingleInstanceGuardState();
}

class _SingleInstanceGuardState extends State<SingleInstanceGuard> {
  bool _isLockedOut = false;
  late final PlatformStorage _storage;
  StreamSubscription<InstanceLockEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _storage = LocalDatabase().platformStorage;
    _checkLock();
    _sub = _storage.lockEvents.listen((event) {
      if (!mounted) return;
      if (event == InstanceLockEvent.lostLock) {
        setState(() => _isLockedOut = true);
      } else if (event == InstanceLockEvent.acquiredLock) {
        setState(() => _isLockedOut = false);
      }
    });
  }

  Future<void> _checkLock() async {
    final acquired = await _storage.acquireLock(forceTakeover: false);
    if (mounted) {
      setState(() => _isLockedOut = !acquired);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLockedOut) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFDFE4ED)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
                    ),
                    child: const Icon(
                      Icons.phonelink_lock_rounded,
                      size: 40,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Application déjà active',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppTheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Une session MRixk est déjà en cours d\'utilisation sur cet appareil.\n\nEn condition normale, une seule instance active est autorisée à la fois sur un même appareil afin de garantir la cohérence des clés souveraines et éviter tout conflit local.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.sync_alt_rounded, size: 20),
                      label: const Text(
                        'Utiliser cette fenêtre (Prendre le contrôle)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: () async {
                        await _storage.acquireLock(forceTakeover: true);
                        if (mounted) {
                          setState(() => _isLockedOut = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Ou fermez cette fenêtre pour continuer sur votre session active.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
