import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../screens/login_screen.dart';
import '../services/account_deletion_service.dart';

class ProfileDeleteAccountTile extends ConsumerStatefulWidget {
  const ProfileDeleteAccountTile({super.key});

  @override
  ConsumerState<ProfileDeleteAccountTile> createState() =>
      _ProfileDeleteAccountTileState();
}

class _ProfileDeleteAccountTileState
    extends ConsumerState<ProfileDeleteAccountTile> {
  bool _isDeleting = false;

  Future<void> _confirmAndDelete(AppUser? user) async {
    if (_isDeleting || user?.isPendingDeletion == true) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('account_deletion_title'.tr()),
        content: SingleChildScrollView(
          child: Text('account_deletion_confirm_body'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('account_deletion_confirm_action'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final result = await AccountDeletionService(
        subscriptionService: ref.read(subscriptionServiceProvider),
      ).requestAccountDeletion();

      if (!mounted) return;

      if (result.deletedImmediately) {
        await ref.read(authServiceProvider).logoutAndClearCache();
        invalidateAuthSessionCache(ref);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      await refreshAuthSessionFromFirestore(ref);
      if (!mounted) return;

      final formattedDate =
          DateFormat.yMMMMd(context.locale.toString()).format(result.scheduledAt);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'account_deletion_scheduled_snackbar'.tr(
              namedArgs: {'date': formattedDate},
            ),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } on AccountDeletionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDocProvider).valueOrNull;
    final isPending = user?.isPendingDeletion == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPending) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, color: Colors.orange.shade900),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pendingDeletionMessage(context, user),
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        ListTile(
          enabled: !_isDeleting && !isPending,
          leading: Icon(
            Icons.delete_forever_outlined,
            color: isPending ? Colors.grey : Colors.red.shade700,
          ),
          title: Text(
            'account_deletion_tile_title'.tr(),
            style: TextStyle(
              color: isPending ? Colors.grey : Colors.red.shade700,
            ),
          ),
          subtitle: Text(
            isPending
                ? 'account_deletion_tile_pending'.tr()
                : 'account_deletion_tile_subtitle'.tr(),
          ),
          trailing: _isDeleting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: isPending ? null : () => _confirmAndDelete(user),
        ),
      ],
    );
  }

  String _pendingDeletionMessage(BuildContext context, AppUser? user) {
    final scheduled = user?.accountDeletionScheduledAt?.toDate().toLocal();
    if (scheduled == null) {
      return 'account_deletion_pending_generic'.tr();
    }
    final formattedDate =
        DateFormat.yMMMMd(context.locale.toString()).format(scheduled);
    return 'account_deletion_pending_until'.tr(
      namedArgs: {'date': formattedDate},
    );
  }
}
