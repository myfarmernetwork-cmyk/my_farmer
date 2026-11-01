import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../repositories/admin_repository.dart';
import '../../models/subscription_tier.dart';
import '../../utils/admin_subscription_summary.dart';
import '../../utils/admin_user_attribution.dart';
import '../../utils/admin_user_presence.dart';
import '../../utils/scroll_bottom_padding.dart';
import '../chat/chat_screen.dart';
import 'admin_media_moderation_screen.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({
    super.key,
    required this.filter,
    this.title,
    this.titleKey,
  }) : assert(title != null || titleKey != null);

  final AdminUserListFilter filter;
  final String? title;
  final String? titleKey;

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final _repo = AdminRepository();
  final _searchController = TextEditingController();
  final Set<String> _processing = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterUsers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return docs;
    return docs.where((doc) {
      final data = doc.data();
      final email = data['email']?.toString().toLowerCase() ?? '';
      final name = data['name']?.toString().toLowerCase() ?? '';
      return email.contains(q) || name.contains(q);
    }).toList();
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      final hour = d.hour.toString().padLeft(2, '0');
      final minute = d.minute.toString().padLeft(2, '0');
      return '$day.$month.${d.year} $hour:$minute';
    }
    return '—';
  }

  bool _isUserActive(Map<String, dynamic> data) {
    return data['isActive'] as bool? ?? true;
  }

  Future<void> _toggleUserActive({
    required String uid,
    required bool currentlyActive,
    required String displayName,
  }) async {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
    if (currentAdminId == uid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ne možete blokirati vlastiti admin račun.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _processing.add(uid));
    try {
      await _repo.setUserActive(uid: uid, isActive: !currentlyActive);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyActive
                ? '$displayName je blokiran.'
                : '$displayName je ponovo aktiviran.',
          ),
          backgroundColor: currentlyActive ? Colors.red : Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(uid));
    }
  }

  static const _adminRoleChoices = <UserRole>[
    UserRole.buyer,
    UserRole.hobbyFarmer,
    UserRole.professionalFarmer,
    UserRole.veterinarian,
    UserRole.pharmacy,
  ];

  Future<void> _changeUserRole({
    required String uid,
    required String displayName,
    required String currentRoleFirestore,
  }) async {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
    if (currentAdminId == uid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ne možete mijenjati vlastitu ulogu ovdje.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentCanonical =
        AppUser.normalizeRoleAlias(currentRoleFirestore);
    UserRole selected = UserRole.buyer;
    for (final role in _adminRoleChoices) {
      if (AppUser.roleToFirestore(role) == currentCanonical) {
        selected = role;
        break;
      }
    }

    final productCount = await _repo.countProductsForSeller(uid);
    if (!mounted) return;

    final confirmed = await showDialog<_AdminRoleChangeChoice>(
      context: context,
      builder: (ctx) {
        var choice = selected;
        var deleteProducts = productCount > 0 && choice == UserRole.buyer;
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Promijeni ulogu'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$displayName\n\n'
                    'Kupac: u Firestoreu se uklanjaju admin premium polja. '
                    'Ostali podaci (chat, narudžbe) ostaju.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    value: choice,
                    decoration: const InputDecoration(
                      labelText: 'Nova uloga',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final role in _adminRoleChoices)
                        DropdownMenuItem(
                          value: role,
                          child: Text(
                            AdminRepository.roleLabel(
                              AppUser.roleToFirestore(role),
                            ),
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() {
                        choice = v;
                        if (v != UserRole.buyer) {
                          deleteProducts = false;
                        } else if (productCount > 0) {
                          deleteProducts = true;
                        }
                      });
                    },
                  ),
                  if (choice == UserRole.buyer && productCount > 0) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: deleteProducts,
                      onChanged: (v) =>
                          setLocal(() => deleteProducts = v ?? false),
                      title: Text(
                        'Obriši proizvode s tržnice ($productCount)',
                      ),
                      subtitle: const Text(
                        'Trajno uklanja oglase i slike u Storage. '
                        'Preporučeno za testere prebačene na kupca.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('cart_cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  _AdminRoleChangeChoice(
                    role: choice,
                    deleteProducts:
                        choice == UserRole.buyer && deleteProducts,
                  ),
                ),
                child: const Text('Spremi ulogu'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed == null) return;

    setState(() => _processing.add(uid));
    try {
      await _repo.setUserRole(uid: uid, newRole: confirmed.role);
      var deletedProducts = 0;
      if (confirmed.deleteProducts) {
        deletedProducts =
            await _repo.deleteAllProductsForSeller(sellerId: uid);
      }
      if (!mounted) return;
      Navigator.pop(context);
      final roleLabel = AdminRepository.roleLabel(
        AppUser.roleToFirestore(confirmed.role),
      );
      final productsLine = confirmed.deleteProducts
          ? ' Obrisano proizvoda: $deletedProducts.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uloga za $displayName: $roleLabel.$productsLine '
            'Korisnik neka se odjavi i ponovo prijavi.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 7),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(uid));
    }
  }

  Future<void> _grantAdminPremium({
    required String uid,
    required String displayName,
    required String roleFirestore,
  }) async {
    final defaultTier = AdminRepository.defaultTierForRoleString(roleFirestore);
    SubscriptionTier selectedTier = defaultTier;
    var unlimited = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Dodijeli Premium (admin)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$displayName\n\n'
                    'Bez Google Play — za testere ili posebne slučajeve. '
                    'Korisnik ne mora plaćati u appu.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SubscriptionTier>(
                    value: selectedTier,
                    decoration: const InputDecoration(
                      labelText: 'Paket',
                      border: OutlineInputBorder(),
                    ),
                    items: SubscriptionTier.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(_tierAdminLabel(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => selectedTier = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bez roka trajanja'),
                    subtitle: const Text('Inače 90 dana od danas'),
                    value: unlimited,
                    onChanged: (v) => setLocal(() => unlimited = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cart_cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Dodijeli'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _processing.add(uid));
    try {
      final expires = unlimited
          ? null
          : DateTime.now().add(const Duration(days: 90));
      await _repo.grantAdminPremium(
        uid: uid,
        tier: selectedTier,
        expiresAt: expires,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Premium dodijeljen: $displayName (${_tierAdminLabel(selectedTier)}).',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(uid));
    }
  }

  Future<void> _revokeAdminPremium({
    required String uid,
    required String displayName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ukloni admin Premium'),
        content: Text(
          'Ukloniti admin-dodijeljen Premium za $displayName?\n\n'
          'Play pretplata (ako postoji) nije otkazana — samo ručni grant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: const Text('Ukloni'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing.add(uid));
    try {
      await _repo.revokeAdminPremium(uid: uid);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin Premium uklonjen: $displayName'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(uid));
    }
  }

  String _tierAdminLabel(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.buyerPremium:
        return 'Kupac Premium';
      case SubscriptionTier.hobbyFarmerPremium:
        return 'Hobi Premium';
      case SubscriptionTier.professionalFarmerPremium:
        return 'Pro Premium';
      case SubscriptionTier.veterinarianLicense:
        return 'Veterinar licenca';
      case SubscriptionTier.pharmacyLicense:
        return 'Tvrtka licenca';
    }
  }

  Future<void> _resetUsageQuotas({
    required String uid,
    required String displayName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset kvota'),
        content: Text(
          'Resetirati AI skener i NIRS brojače za $displayName?\n\n'
          'Postavlja mjesečne AI skenove, uvodni sken, bonus skenove, NIRS učitavanja, trial i free scan zastavice na početno.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resetiraj'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing.add(uid));
    try {
      await _repo.resetUserUsageQuotas(uid: uid);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kvote resetirane za $displayName.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(uid));
    }
  }

  Future<void> _clearProfilePhoto({
    required String uid,
    required String displayName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin_clear_profile_photo_title'.tr()),
        content: Text(
          'admin_clear_profile_photo_body'.tr(namedArgs: {'name': displayName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            child: Text('admin_clear_profile_photo_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing.add(uid));
    try {
      await _repo.clearUserProfileImage(uid: uid);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin_clear_profile_photo_success'.tr(
              namedArgs: {'name': displayName},
            ),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(uid));
    }
  }

  Future<void> _deleteUserAccount({
    required String uid,
    required String displayName,
    required Map<String, dynamic> data,
  }) async {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
    if (currentAdminId == uid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin_delete_user_blocked_self'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final role = AppUser.normalizeRoleAlias(data['role']?.toString());
    final isTargetAdmin =
        role == 'admin' || data['isAdmin'] == true;
    if (isTargetAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin_delete_user_blocked_admin'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin_delete_user_title'.tr()),
        content: Text(
          'admin_delete_user_body'.tr(namedArgs: {'name': displayName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: Text('admin_delete_user_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing.add(uid));
    try {
      await _repo.deleteUserAccount(uid: uid);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin_delete_user_success'.tr(namedArgs: {'name': displayName}),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(uid));
    }
  }

  Future<void> _showUserDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final uid = doc.id;
    final name = data['name']?.toString().trim();
    final email = data['email']?.toString().trim() ?? '—';
    final phone = data['phone']?.toString().trim() ?? '—';
    final address = data['address']?.toString().trim() ?? '—';
    final role = AdminRepository.roleLabel(data['role']?.toString());
    final createdAt = _formatDate(data['createdAt']);
    final status = data['status']?.toString() ?? '—';
    final isActive = _isUserActive(data);
    final license = data['veterinaryLicense']?.toString() ??
        data['companyRegistrationNumber']?.toString() ??
        data['extraInfo']?.toString();
    final profileImageUrl = data['profileImageUrl']?.toString().trim();
    final hasProfilePhoto =
        profileImageUrl != null && profileImageUrl.isNotEmpty;
    final displayName =
        name?.isNotEmpty == true ? name! : 'Bez imena';
    final isProcessing = _processing.contains(uid);
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
    final canMessage = currentAdminId != null && currentAdminId != uid;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(displayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasProfilePhoto) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      profileImageUrl,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _detailLine('Email', email),
              _detailLine('Telefon', phone),
              _detailLine('Adresa', address),
              _detailLine('Uloga', role),
              _detailLine('Status', status),
              _detailLine(
                'Račun',
                isActive ? 'Aktivan' : 'Blokiran',
              ),
              _detailLine('Registracija', createdAt),
              _detailLine(
                'Zemlja (signup)',
                AdminUserAttribution.countryLabel(
                  data['signupCountryCode']?.toString(),
                ),
              ),
              if (data['signupIpCountryCode'] != null)
                _detailLine(
                  'Zemlja (IP signup)',
                  AdminUserAttribution.countryLabel(
                    data['signupIpCountryCode']?.toString(),
                  ),
                ),
              _detailLine(
                'Zadnja zemlja (app)',
                AdminUserAttribution.countryLabel(
                  data['lastSeenCountryCode']?.toString(),
                ),
              ),
              _detailLine(
                'Jezik appa',
                AdminUserAttribution.localeLabel(data),
              ),
              _detailLine(
                'Platforma',
                AdminUserAttribution.platformLabel(data),
              ),
              _detailLine(
                'Verzija signup',
                AdminUserAttribution.signupVersion(data),
              ),
              if (data['signupSource'] != null)
                _detailLine(
                  'Izvor',
                  data['signupSource']?.toString() ?? '—',
                ),
              _detailLine(
                'admin_presence_status_label'.tr(),
                adminPresenceSummary(data),
              ),
              _detailLine(
                'Kvote',
                AdminRepository.usageQuotaSummary(data),
              ),
              _detailLine(
                'Pretplata',
                AdminSubscriptionSummary.format(data),
              ),
              if (license != null && license.isNotEmpty)
                _detailLine('Dokument', license),
              if (hasProfilePhoto) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _clearProfilePhoto(
                              uid: uid,
                              displayName: displayName,
                            ),
                    icon: const Icon(Icons.hide_image_outlined),
                    label: Text('admin_clear_profile_photo'.tr()),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminMediaModerationScreen(
                                userId: uid,
                                userName: displayName,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.collections_outlined),
                  label: Text('admin_user_media'.tr()),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _deleteUserAccount(
                            uid: uid,
                            displayName: displayName,
                            data: data,
                          ),
                  icon: const Icon(Icons.person_off_outlined),
                  label: Text('admin_delete_user'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _grantAdminPremium(
                            uid: uid,
                            displayName: displayName,
                            roleFirestore: data['role']?.toString() ?? 'buyer',
                          ),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('Dodijeli Premium (admin)'),
                ),
              ),
              if (AdminSubscriptionSummary.hasAdminGrant(data)) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _revokeAdminPremium(
                              uid: uid,
                              displayName: displayName,
                            ),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Ukloni admin Premium'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _changeUserRole(
                            uid: uid,
                            displayName: displayName,
                            currentRoleFirestore:
                                data['role']?.toString() ?? 'buyer',
                          ),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Promijeni ulogu'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _resetUsageQuotas(
                            uid: uid,
                            displayName: displayName,
                          ),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset skenova / NIRS'),
                ),
              ),
              if (canMessage) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            receiverId: uid,
                            receiverName: displayName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text('admin_send_message'.tr()),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cart_cancel'.tr()),
          ),
          FilledButton.icon(
            onPressed: isProcessing
                ? null
                : () => _toggleUserActive(
                      uid: uid,
                      currentlyActive: isActive,
                      displayName: displayName,
                    ),
            style: FilledButton.styleFrom(
              backgroundColor: isActive ? Colors.red.shade700 : Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            icon: Icon(isActive ? Icons.block : Icons.check_circle_outline),
            label: Text(
              isActive ? 'Blokiraj korisnika' : 'Aktiviraj račun',
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _appBarTitle =>
      widget.titleKey?.tr() ?? widget.title ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Pretraži email ili ime…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _repo.usersForFilter(widget.filter),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Greška: ${snapshot.error}'));
          }

          final docs = _filterUsers(snapshot.data ?? []);
          if (docs.isEmpty) {
            final rawEmpty = (snapshot.data ?? []).isEmpty;
            return Center(
              child: Text(
                rawEmpty
                    ? _emptyMessage(widget.filter)
                    : 'Nema korisnika za „${_searchController.text.trim()}“.',
              ),
            );
          }

          return ListView.separated(
            padding: ScrollBottomPadding.list(context),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = data['name']?.toString().trim();
              final email = data['email']?.toString().trim() ?? '—';
              final role =
                  AdminRepository.roleLabel(data['role']?.toString());
              final createdAt = _formatDate(data['createdAt']);
              final isActive = _isUserActive(data);
              final presenceLine = adminPresenceSummary(data);
              final license = data['veterinaryLicense']?.toString() ??
                  data['companyRegistrationNumber']?.toString() ??
                  data['extraInfo']?.toString();

              return Card(
                color: isActive ? null : Colors.red.shade50,
                child: ListTile(
                  onTap: () => _showUserDialog(doc),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: isActive
                            ? Colors.purple.shade100
                            : Colors.red.shade100,
                        child: Icon(
                          isActive ? Icons.person : Icons.block,
                          color: isActive
                              ? Colors.purple.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: adminPresenceIndicator(data: data),
                      ),
                    ],
                  ),
                  title: Text(
                    name?.isNotEmpty == true ? name! : 'Bez imena',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      email,
                      AdminUserAttribution.listSubtitleLine(data),
                      'Uloga: $role',
                      presenceLine,
                      'Registracija: $createdAt',
                      if (!isActive) 'Status: BLOKIRAN',
                      if (widget.filter == AdminUserListFilter.pendingPremium &&
                          license != null &&
                          license.isNotEmpty)
                        'Dokument: $license',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _emptyMessage(AdminUserListFilter filter) {
    switch (filter) {
      case AdminUserListFilter.pendingPremium:
        return 'admin_licenses_empty'.tr();
      case AdminUserListFilter.buyer:
        return 'Nema registriranih kupaca.';
      case AdminUserListFilter.hobbyFarmer:
        return 'Nema hobi farmera.';
      case AdminUserListFilter.professionalFarmer:
        return 'Nema profesionalnih farmera.';
      case AdminUserListFilter.veterinarian:
        return 'Nema veterinara.';
      case AdminUserListFilter.pharmacy:
        return 'Nema tvrtki / agro-apoteka.';
      case AdminUserListFilter.admin:
        return 'Nema admin korisnika.';
      case AdminUserListFilter.all:
        return 'Nema korisnika.';
    }
  }
}

class _AdminRoleChangeChoice {
  const _AdminRoleChangeChoice({
    required this.role,
    required this.deleteProducts,
  });

  final UserRole role;
  final bool deleteProducts;
}
