import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

class AdminModerationException implements Exception {
  AdminModerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminModerationService {
  AdminModerationService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> clearUserProfileImage({required String targetUid}) async {
    await _call('adminClearUserProfileImage', {'targetUid': targetUid});
  }

  Future<void> deleteUserAccount({required String targetUid}) async {
    await _call('adminDeleteUserAccount', {'targetUid': targetUid});
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      final callable = _functions.httpsCallable(name);
      await callable.call<Object?>(data);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('$name: ${e.code} ${e.message}');
      }
      throw AdminModerationException(_mapError(e));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('$name: $e');
      }
      throw AdminModerationException('admin_moderation_failed'.tr());
    }
  }

  String _mapError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'permission-denied':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'admin_moderation_permission_denied'.tr();
      case 'not-found':
        return 'admin_moderation_user_not_found'.tr();
      case 'unauthenticated':
        return 'admin_moderation_login_required'.tr();
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'admin_moderation_failed'.tr();
    }
  }
}
