import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../repositories/admin_repository.dart';
import 'admin_orders_list_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_user_list_screen.dart';
import 'admin_verification_screen.dart';
import 'admin_reported_posts_screen.dart';
import '../../screens/roles_subscription_pdf_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repo = AdminRepository();

  String _pendingBannerText(BuildContext context, int count) {
    final lang = context.locale.languageCode;
    if (lang == 'de') {
      return '⚠️ Achtung: Sie haben $count neue Lizenzanträge, die auf Ihre Genehmigung warten!';
    }
    return '⚠️ Pozor: Imate $count novih zahtjeva za licencu koji čekaju vaše odobrenje!';
  }

  int _countRole(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool Function(String role) match,
  ) {
    return docs.where((doc) {
      final role =
          AppUser.normalizeRoleAlias(doc.data()['role']?.toString());
      return match(role);
    }).length;
  }

  int _countPendingPremium(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      if (!AdminRepository.isVerificationRole(data['role']?.toString())) {
        return false;
      }
      final status =
          data['premiumApprovalStatus']?.toString().trim().toUpperCase() ?? '';
      return status == 'PENDING';
    }).length;
  }

  void _openUserList({
    required AdminUserListFilter filter,
    String? title,
    String? titleKey,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserListScreen(
          filter: filter,
          title: title,
          titleKey: titleKey,
        ),
      ),
    );
  }

  Widget _buildPendingApprovalsBanner(BuildContext context, int count) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminVerificationScreen(),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepOrange.shade300, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.deepOrange.shade800,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _pendingBannerText(context, count),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepOrange.shade900,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.deepOrange.shade700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color),
          ),
          title: Text(title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.orangeAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _repo.pendingVerifications(),
        builder: (context, pendingSnap) {
          final pendingApprovalsCount = pendingSnap.data?.length ?? 0;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _repo.allUsers(),
            builder: (context, usersSnap) {
              final userDocs = usersSnap.data?.docs ?? [];
              final pendingPremium = _countPendingPremium(userDocs);
              final buyers =
                  _countRole(userDocs, (r) => r == 'buyer' || r.isEmpty);
              final hobby = _countRole(userDocs, (r) => r == 'hobby_farmer');
              final pro =
                  _countRole(userDocs, (r) => r == 'professional_farmer');
              final vets = _countRole(userDocs, (r) => r == 'veterinarian');
              final firms = _countRole(userDocs, (r) => r == 'pharmacy');

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .snapshots(),
                builder: (context, ordersSnap) {
                  final orderCount = ordersSnap.data?.docs.length ?? 0;

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (pendingApprovalsCount > 0) ...[
                          _buildPendingApprovalsBanner(
                            context,
                            pendingApprovalsCount,
                          ),
                          const SizedBox(height: 16),
                        ],
                        Expanded(
                          child: ListView(
                            children: [
                              const Text(
                                'Živa statistika',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildLiveStatTile(
                                title: 'Narudžbe',
                                value: '$orderCount',
                                icon: Icons.shopping_cart,
                                color: Colors.indigo,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AdminOrdersListScreen(),
                                  ),
                                ),
                              ),
                              _buildLiveStatTile(
                                title: 'Na čekanju (Premium)',
                                value: '$pendingPremium',
                                icon: Icons.hourglass_top,
                                color: Colors.orange,
                                onTap: () => _openUserList(
                                  filter: AdminUserListFilter.pendingPremium,
                                  titleKey: 'admin_licenses_title',
                                ),
                              ),
                              _buildLiveStatTile(
                                title: 'Kupci',
                                value: '$buyers',
                                icon: Icons.person,
                                color: Colors.teal,
                                onTap: () => _openUserList(
                                  filter: AdminUserListFilter.buyer,
                                  title: 'Kupci',
                                ),
                              ),
                              _buildLiveStatTile(
                                title: 'Hobi Farmeri',
                                value: '$hobby',
                                icon: Icons.yard,
                                color: Colors.lightGreen,
                                onTap: () => _openUserList(
                                  filter: AdminUserListFilter.hobbyFarmer,
                                  title: 'Hobi Farmeri',
                                ),
                              ),
                              _buildLiveStatTile(
                                title: 'Pro Farmeri',
                                value: '$pro',
                                icon: Icons.agriculture,
                                color: Colors.green.shade800,
                                onTap: () => _openUserList(
                                  filter: AdminUserListFilter.professionalFarmer,
                                  title: 'Profesionalni Farmeri',
                                ),
                              ),
                              _buildLiveStatTile(
                                title: 'Veterinari',
                                value: '$vets',
                                icon: Icons.medical_services,
                                color: Colors.teal.shade700,
                                onTap: () => _openUserList(
                                  filter: AdminUserListFilter.veterinarian,
                                  title: 'Veterinari',
                                ),
                              ),
                              _buildLiveStatTile(
                                title: 'Tvrtke / Apoteke',
                                value: '$firms',
                                icon: Icons.business,
                                color: Colors.deepPurple,
                                onTap: () => _openUserList(
                                  filter: AdminUserListFilter.pharmacy,
                                  title: 'Tvrtke / Agro-apoteke',
                                ),
                              ),
                              _buildLiveStatTile(
                                title: 'Svi korisnici',
                                value: '${userDocs.length}',
                                icon: Icons.people,
                                color: Colors.blue,
                                onTap: () => _openUserList(
                                  filter: AdminUserListFilter.all,
                                  title: 'Svi korisnici',
                                ),
                              ),
                              const Divider(height: 32),
                              const Text(
                                'Administracija',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                                children: [
                                  _buildAdminCard(
                                    context,
                                    title: 'Narudžbine',
                                    icon: Icons.shopping_cart_checkout,
                                    color: Colors.blue,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AdminOrdersListScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildAdminCard(
                                    context,
                                    title: 'Statistika',
                                    icon: Icons.bar_chart,
                                    color: Colors.purple,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AdminStatsScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildAdminCard(
                                    context,
                                    title: 'Premium odobrenja',
                                    icon: Icons.verified_user,
                                    color: Colors.deepOrange,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AdminVerificationScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildAdminCard(
                                    context,
                                    title: 'Svi korisnici',
                                    icon: Icons.people,
                                    color: Colors.teal,
                                    onTap: () => _openUserList(
                                      filter: AdminUserListFilter.all,
                                      title: 'Svi korisnici',
                                    ),
                                  ),
                                  _buildAdminCard(
                                    context,
                                    title: 'Prijavljene objave',
                                    icon: Icons.flag,
                                    color: Colors.red,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AdminReportedPostsScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildAdminCard(
                                    context,
                                    title: 'Seller narudžbe',
                                    icon: Icons.receipt_long,
                                    color: Colors.blueGrey,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AdminOrdersScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildAdminCard(
                                    context,
                                    title: 'PDF uloge i pretplate',
                                    icon: Icons.picture_as_pdf_outlined,
                                    color: Colors.green.shade800,
                                    onTap: () => RolesSubscriptionPdfScreen.open(
                                      context,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAdminCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
