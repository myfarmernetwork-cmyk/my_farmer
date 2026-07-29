import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = ref.read(authServiceProvider);
      await authService.ensureActiveSession();
      if (FirebaseAuth.instance.currentUser != null) {
        await refreshAuthSessionFromFirestore(ref);
      }
    });
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
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text("Greška: $error")),
      ),
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        ref.read(authRepositoryProvider).watchAccountBlocked(user.uid);

        return roleAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            body: Center(child: Text("Greška: $error")),
          ),
          data: (role) {
            if (role == null || role.isEmpty) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final isAdminUser = PaymentService.hasAdminPremiumBypass(
              user,
              resolvedFirestoreRole: role,
            );

            return SubscriptionBootstrap(
              userId: user.uid,
              child: LocationRequiredGate(
                child: _AuthenticatedAppShell(
                  initialTabIndex: isAdminUser
                      ? 0
                      : defaultTabIndexForRole(role),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AuthenticatedAppShell extends StatefulWidget {
  const _AuthenticatedAppShell({required this.initialTabIndex});

  final int initialTabIndex;

  @override
  State<_AuthenticatedAppShell> createState() => _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState extends State<_AuthenticatedAppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().flushPendingNavigation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationScreen(initialTabIndex: widget.initialTabIndex);
  }
}
