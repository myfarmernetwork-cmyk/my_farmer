import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import 'subscription_service.dart';

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.scheduledAt,
    required this.keepAccessUntilExpiry,
    required this.deletedImmediately,
  });

  final DateTime scheduledAt;
  final bool keepAccessUntilExpiry;
  final bool deletedImmediately;
}

class AccountDeletionException implements Exception {
  AccountDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountDeletionService {
  AccountDeletionService({
    SubscriptionService? subscriptionService,
    FirebaseFunctions? functions,
  })  : _subscriptionService =
            subscriptionService ?? SubscriptionService(),
        _functions = functions ?? FirebaseFunctions.instance;

  final SubscriptionService _subscriptionService;
  final FirebaseFunctions _functions;

  Future<AccountDeletionResult> requestAccountDeletion() async {
    await _subscriptionService.refreshPremiumStatus();
    final expiry = await _subscriptionService.getActiveSubscriptionExpiry();

    try {
      final callable = _functions.httpsCallable('requestAccountDeletion');
      final response = await callable.call<Object?>({
        if (expiry != null)
          'subscriptionExpiresAt': expiry.toUtc().toIso8601String(),
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final scheduledRaw = data['scheduledAt'] as String?;
      final scheduledAt = scheduledRaw != null
          ? DateTime.tryParse(scheduledRaw) ?? DateTime.now()
          : DateTime.now();

      return AccountDeletionResult(
        scheduledAt: scheduledAt.toLocal(),
        keepAccessUntilExpiry: data['keepAccessUntilExpiry'] as bool? ?? false,
        deletedImmediately: data['deletedImmediately'] as bool? ?? false,
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('requestAccountDeletion: ${e.code} ${e.message}');
      }
      throw AccountDeletionException(_mapFunctionsError(e));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('requestAccountDeletion: $e');
      }
      throw AccountDeletionException('account_deletion_failed'.tr());
    }
  }

  String _mapFunctionsError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'already-exists':
        return 'account_deletion_already_requested'.tr();
      case 'permission-denied':
        return 'account_deletion_admin_blocked'.tr();
      case 'unauthenticated':
        return 'account_deletion_login_required'.tr();
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'account_deletion_failed'.tr();
    }
  }
}
