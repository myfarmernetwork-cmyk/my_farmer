import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../utils/company_scan_copy.dart';

class RoleSelectionScreen extends StatefulWidget {
  final void Function(String roleId)? onRoleSelected;

  const RoleSelectionScreen({super.key, this.onRoleSelected});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleOption {
  final String id;
  final IconData icon;
  final Color color;
  final String titleKey;
  final String infoKey;

  const _RoleOption({
    required this.id,
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.infoKey,
  });
}

const _roles = [
  _RoleOption(
    id: 'buyer',
    icon: Icons.pets,
    color: Colors.blue,
    titleKey: 'role_buyer',
    infoKey: 'role_buyer_info',
  ),
  _RoleOption(
    id: 'hobby_farmer',
    icon: Icons.yard,
    color: Colors.lightGreen,
    titleKey: 'role_hobby_farmer',
    infoKey: 'role_hobby_farmer_info',
  ),
  _RoleOption(
    id: 'professional_farmer',
    icon: Icons.agriculture,
    color: Colors.orange,
    titleKey: 'role_professional_farmer',
    infoKey: 'role_professional_farmer_info',
  ),
  _RoleOption(
    id: 'veterinarian',
    icon: Icons.medical_services,
    color: Colors.teal,
    titleKey: 'role_veterinarian',
    infoKey: 'role_veterinarian_info',
  ),
  _RoleOption(
    id: 'pharmacy',
    icon: Icons.business,
    color: Colors.deepPurple,
    titleKey: 'role_company',
    infoKey: 'role_company_info',
  ),
];

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  void _showRoleInfo(_RoleOption role) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(role.titleKey.tr()),
        content: SingleChildScrollView(
          child: Text(
            role.id == 'pharmacy'
                ? companyRoleInfoForContext(context)
                : role.infoKey.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  void _confirmSelection() {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('role_select_required'.tr())),
      );
      return;
    }
    widget.onRoleSelected?.call(_selectedRole!);
    Navigator.pop(context, _selectedRole);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('role_selection'.tr()),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                children: [
                  Text(
                    'role_selection'.tr(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'role_selection_hint'.tr(),
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _roles.length,
                itemBuilder: (context, index) {
                  final role = _roles[index];
                  final isSelected = _selectedRole == role.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: isSelected
                          ? role.color.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedRole = role.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? role.color
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    isSelected ? role.color : Colors.grey[200],
                                child: Icon(
                                  role.icon,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  role.titleKey.tr(),
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? role.color
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.info_outline, color: role.color),
                                tooltip: 'role_info'.tr(),
                                onPressed: () => _showRoleInfo(role),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, color: role.color),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'ok'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
