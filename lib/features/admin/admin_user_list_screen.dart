import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/admin_repository.dart';

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
  final Set<String> _processing = {};

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
    final displayName =
        name?.isNotEmpty == true ? name! : 'Bez imena';
    final isProcessing = _processing.contains(uid);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(displayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (license != null && license.isNotEmpty)
                _detailLine('Dokument', license),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
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

          final docs = snapshot.data ?? [];
          if (docs.isEmpty) {
            return Center(child: Text(_emptyMessage(widget.filter)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
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
              final license = data['veterinaryLicense']?.toString() ??
                  data['companyRegistrationNumber']?.toString() ??
                  data['extraInfo']?.toString();

              return Card(
                color: isActive ? null : Colors.red.shade50,
                child: ListTile(
                  onTap: () => _showUserDialog(doc),
                  leading: CircleAvatar(
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
                  title: Text(
                    name?.isNotEmpty == true ? name! : 'Bez imena',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      email,
                      'Uloga: $role',
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
