import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../utils/firestore_error_helper.dart';

/// Full-screen or inline panel for Firestore load / permission failures.
class FirestoreErrorPanel extends StatelessWidget {
  const FirestoreErrorPanel({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final message = firestoreErrorMessage(error);
    final title = firestoreErrorTitle(error);
    final code = firestoreErrorCode(error);
    final isAuth = firestoreErrorIsAuthRelated(error);
    final padding = compact ? 16.0 : 24.0;

    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isAuth ? Icons.lock_outline : Icons.cloud_off_outlined,
                  size: compact ? 48 : 56,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (code != null && code.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'firestore_error_code'.tr(namedArgs: {'code': code}),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text('firestore_error_retry'.tr()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
