import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../repositories/admin_repository.dart';
import 'admin_orders_list_screen.dart';
import 'admin_user_list_screen.dart';
import 'widgets/admin_stats_charts.dart';

class AdminStatsScreen extends StatelessWidget {
  const AdminStatsScreen({super.key});

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

  List<AdminRoleSlice> _roleSlices({
    required int buyers,
    required int hobby,
    required int pro,
    required int vets,
    required int firms,
    required int admins,
  }) {
    return [
      AdminRoleSlice(label: 'Kupci', value: buyers, color: Colors.teal),
      AdminRoleSlice(
        label: 'Hobi Farmeri',
        value: hobby,
        color: Colors.lightGreen.shade700,
      ),
      AdminRoleSlice(
        label: 'Pro Farmeri',
        value: pro,
        color: Colors.green.shade800,
      ),
      AdminRoleSlice(
        label: 'Veterinari',
        value: vets,
        color: Colors.teal.shade700,
      ),
      AdminRoleSlice(
        label: 'Tvrtke',
        value: firms,
        color: Colors.deepPurple,
      ),
      AdminRoleSlice(label: 'Admini', value: admins, color: Colors.orange),
    ];
  }

  void _openList(
    BuildContext context, {
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

  @override
  Widget build(BuildContext context) {
    final repo = AdminRepository();
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistika'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.allUsers(),
        builder: (context, usersSnap) {
          if (usersSnap.connectionState == ConnectionState.waiting &&
              !usersSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (usersSnap.hasError) {
            return Center(child: Text('Greška: ${usersSnap.error}'));
          }

          final userDocs = usersSnap.data?.docs ?? [];
          final pendingPremium = _countPendingPremium(userDocs);
          final buyers =
              _countRole(userDocs, (r) => r == 'buyer' || r.isEmpty);
          final hobby = _countRole(userDocs, (r) => r == 'hobby_farmer');
          final pro =
              _countRole(userDocs, (r) => r == 'professional_farmer');
          final vets = _countRole(userDocs, (r) => r == 'veterinarian');
          final firms = _countRole(userDocs, (r) => r == 'pharmacy');
          final admins = _countRole(userDocs, (r) => r == 'admin');
          final roleSlices = _roleSlices(
            buyers: buyers,
            hobby: hobby,
            pro: pro,
            vets: vets,
            firms: firms,
            admins: admins,
          );

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firestore.collection('orders').snapshots(),
            builder: (context, ordersSnap) {
              final orderDocs = ordersSnap.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firestore.collection('scan_history').snapshots(),
                builder: (context, scansSnap) {
                  final scanDocs = scansSnap.data?.docs ?? [];
                  final usageDays = adminBuildUsageDays(
                    users: userDocs,
                    orders: orderDocs,
                    scans: scanDocs,
                  );

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AdminChartCard(
                        title: 'Dijagram korisnika',
                        subtitle: 'Raspodjela po ulogama',
                        child: AdminUserPieChart(slices: roleSlices),
                      ),
                      AdminChartCard(
                        title: 'Dijagram korištenja',
                        subtitle: 'Aktivnost u zadnjih 7 dana',
                        child: AdminUsageBarChart(days: usageDays),
                      ),
                      const Divider(height: 32),
                      _StatCard(
                        title: 'Ukupno korisnika',
                        value: '${userDocs.length}',
                        icon: Icons.people,
                        color: Colors.blue,
                        onTap: () => _openList(
                          context,
                          filter: AdminUserListFilter.all,
                          title: 'Svi korisnici',
                        ),
                      ),
                      _StatCard(
                        title: 'Narudžbe',
                        value: '${orderDocs.length}',
                        icon: Icons.shopping_cart,
                        color: Colors.indigo,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminOrdersListScreen(),
                          ),
                        ),
                      ),
                      _StatCard(
                        title: 'Na čekanju (Premium)',
                        value: '$pendingPremium',
                        icon: Icons.hourglass_top,
                        color: Colors.orange,
                        onTap: () => _openList(
                          context,
                          filter: AdminUserListFilter.pendingPremium,
                          titleKey: 'admin_licenses_title',
                        ),
                      ),
                      const Divider(height: 32),
                      _StatCard(
                        title: 'Kupci',
                        value: '$buyers',
                        icon: Icons.person,
                        color: Colors.teal,
                        onTap: () => _openList(
                          context,
                          filter: AdminUserListFilter.buyer,
                          title: 'Kupci',
                        ),
                      ),
                      _StatCard(
                        title: 'Hobi Farmeri',
                        value: '$hobby',
                        icon: Icons.yard,
                        color: Colors.lightGreen,
                        onTap: () => _openList(
                          context,
                          filter: AdminUserListFilter.hobbyFarmer,
                          title: 'Hobi Farmeri',
                        ),
                      ),
                      _StatCard(
                        title: 'Pro Farmeri',
                        value: '$pro',
                        icon: Icons.agriculture,
                        color: Colors.green.shade800,
                        onTap: () => _openList(
                          context,
                          filter: AdminUserListFilter.professionalFarmer,
                          title: 'Profesionalni Farmeri',
                        ),
                      ),
                      _StatCard(
                        title: 'Veterinari',
                        value: '$vets',
                        icon: Icons.medical_services,
                        color: Colors.teal.shade700,
                        onTap: () => _openList(
                          context,
                          filter: AdminUserListFilter.veterinarian,
                          title: 'Veterinari',
                        ),
                      ),
                      _StatCard(
                        title: 'Tvrtke / Apoteke',
                        value: '$firms',
                        icon: Icons.business,
                        color: Colors.deepPurple,
                        onTap: () => _openList(
                          context,
                          filter: AdminUserListFilter.pharmacy,
                          title: 'Tvrtke / Agro-apoteke',
                        ),
                      ),
                      _StatCard(
                        title: 'Admini',
                        value: '$admins',
                        icon: Icons.admin_panel_settings,
                        color: Colors.orange,
                        onTap: () => _openList(
                          context,
                          filter: AdminUserListFilter.admin,
                          title: 'Admini',
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
