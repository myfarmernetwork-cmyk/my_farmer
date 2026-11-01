import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../utils/firestore_error_helper.dart';
import '../widgets/firestore_error_panel.dart';
import '../widgets/subscription_bootstrap.dart';
import '../widgets/location_required_gate.dart';
import '../services/payment_service.dart';
import '../services/notification_service.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  void _retrySessionLoad() {
    invalidateAuthSessionCache(ref);
  }

  Future<void> _logoutAndRetry() async {
    await ref.read(authServiceProvider).logoutAndClearCache();
    invalidateAuthSessionCache(ref);
  }

  Widget _sessionErrorScaffold(Object error) {
    final authRelated = firestoreErrorIsAuthRelated(error);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FirestoreErrorPanel(
                error: error,
                onRetry: authRelated ? null : _retrySessionLoad,
              ),
            ),
            if (authRelated)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _logoutAndRetry,
                    child: Text(firestoreErrorLogoutLabel()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppUser?>>(authStateProvider, (previous, next) {
      final repo = ref.read(authRepositoryProvider);
      next.whenOrNull(
        data: (user) {
          if (user != null) {
            repo.watchAccountBlocked(user.uid);
          } else {
            repo.stopWatchingAccount();
          }
        },
      );
    });

    final authState = ref.watch(authStateProvider);
    final roleAsync = ref.watch(firestoreUserRoleProvider);

    return authState.when(
      loading: () {
        final cached = ref.read(authRepositoryProvider).lastSyncedUser;
        if (cached != null) {
          return _buildAuthenticatedShell(
            user: cached,
            role: cached.roleFirestore,
          );
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) => _sessionErrorScaffold(error),
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        ref.read(authRepositoryProvider).watchAccountBlocked(user.uid);

        return roleAsync.when(
          loading: () {
            final fallbackRole = user.roleFirestore;
            if (fallbackRole.isNotEmpty) {
              return _buildAuthenticatedShell(
                user: user,
                role: fallbackRole,
              );
            }
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
          error: (error, _) {
            final fallbackRole = user.roleFirestore;
            if (fallbackRole.isNotEmpty) {
              return _buildAuthenticatedShell(
                user: user,
                role: fallbackRole,
              );
            }
            return _sessionErrorScaffold(error);
          },
          data: (role) {
            final effectiveRole =
                (role != null && role.isNotEmpty) ? role : user.roleFirestore;
            if (effectiveRole.isEmpty) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return _buildAuthenticatedShell(
              user: user,
              role: effectiveRole,
            );
          },
        );
      },
    );
  }

  Widget _buildAuthenticatedShell({
    required AppUser user,
    required String role,
  }) {
    final isAdminUser = PaymentService.hasAdminPremiumBypass(
      user,
      resolvedFirestoreRole: role,
    );

    return SubscriptionBootstrap(
      key: ValueKey('subscription_${user.uid}'),
      userId: user.uid,
      child: LocationRequiredGate(
        key: ValueKey('location_${user.uid}'),
        child: _AuthenticatedAppShell(
          key: ValueKey('app_shell_${user.uid}'),
          initialTabIndex:
              isAdminUser ? 0 : defaultTabIndexForRole(role),
        ),
      ),
    );
  }
}

class _AuthenticatedAppShell extends StatefulWidget {
  const _AuthenticatedAppShell({super.key, required this.initialTabIndex});

  final int initialTabIndex;

  @override
  State<_AuthenticatedAppShell> createState() => _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState extends State<_AuthenticatedAppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        NotificationService().flushPendingNavigation();
        unawaited(NotificationService().ensurePushReady());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationScreen(initialTabIndex: widget.initialTabIndex);
  }
}
