import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import '../utils/company_scan_copy.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';
import '../widgets/registration_legal_consent.dart';

class _RoleOption {
  final String id;
  final IconData icon;
  final Color color;
  final String titleKey;
  final String descKey;
  final String infoKey;
  final String? extraFieldKey;

  const _RoleOption({
    required this.id,
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.descKey,
    required this.infoKey,
    this.extraFieldKey,
  });
}

const _roles = [
  _RoleOption(
    id: 'buyer',
    icon: Icons.pets,
    color: Colors.blue,
    titleKey: 'role_buyer',
    descKey: 'role_buyer_desc',
    infoKey: 'role_buyer_info',
  ),
  _RoleOption(
    id: 'hobby_farmer',
    icon: Icons.yard,
    color: Colors.lightGreen,
    titleKey: 'role_hobby_farmer',
    descKey: 'role_hobby_farmer_desc',
    infoKey: 'role_hobby_farmer_info',
    extraFieldKey: 'farm_number',
  ),
  _RoleOption(
    id: 'professional_farmer',
    icon: Icons.agriculture,
    color: Colors.orange,
    titleKey: 'role_professional_farmer',
    descKey: 'role_professional_farmer_desc',
    infoKey: 'role_professional_farmer_info',
    extraFieldKey: 'farm_number',
  ),
  _RoleOption(
    id: 'veterinarian',
    icon: Icons.medical_services,
    color: Colors.teal,
    titleKey: 'role_veterinarian',
    descKey: 'role_veterinarian_desc',
    infoKey: 'role_veterinarian_info',
    extraFieldKey: 'veterinary_license',
  ),
  _RoleOption(
    id: 'pharmacy',
    icon: Icons.business,
    color: Colors.deepPurple,
    titleKey: 'role_company',
    descKey: 'role_company_desc',
    infoKey: 'role_company_info',
    extraFieldKey: 'reg_number',
  ),
];

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedRole;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _extraController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _acceptedLegal = false;

  _RoleOption? get _selectedOption {
    if (selectedRole == null) return null;
    return _roles.firstWhere((r) => r.id == selectedRole);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _extraController.dispose();
    super.dispose();
  }

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

  Future<void> _registerUser() async {
    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('role_select_required'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final validationError = _validateFields();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_acceptedLegal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('registration_legal_consent_required'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final role = selectedRole!;
      final appUser = await ref.read(authRepositoryProvider).registerWithProfile(
            email: _emailController.text,
            password: _passwordController.text,
            role: role,
            name: _nameController.text,
            address: _addressController.text,
            phone: _phoneController.text,
            veterinaryLicense:
                role == 'veterinarian' ? _extraController.text : null,
            companyRegistrationNumber:
                role == 'pharmacy' ? _extraController.text : null,
            extraInfo: role == 'hobby_farmer' || role == 'professional_farmer'
                ? _extraController.text
                : '',
          );

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);

      String message;
      if (appUser.isTrialUsed && !appUser.hasFreeScans) {
        message = 'registration_device_trial_used'.tr();
      } else {
        message = 'registration_success'.tr();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String poruka = 'registration_error'.tr();
      if (e.code == 'email-already-in-use') {
        poruka = 'registration_email_in_use'.tr();
      } else if (e.code == 'weak-password') {
        poruka = 'registration_weak_password'.tr();
      } else if (e.code == 'invalid-email') {
        poruka = 'registration_invalid_email'.tr();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(poruka), backgroundColor: Colors.red),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateFields() {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      return 'registration_fields_required'.tr();
    }

    if (selectedRole == 'veterinarian') {
      if (_phoneController.text.trim().isEmpty ||
          _addressController.text.trim().isEmpty ||
          _extraController.text.trim().isEmpty) {
        return 'registration_vet_fields_required'.tr();
      }
    }

    if (selectedRole == 'pharmacy' && _extraController.text.trim().isEmpty) {
      return 'registration_company_reg_required'.tr();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('registration'.tr()),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'role_selection'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._roles.map(_buildRoleTile),
              if (selectedRole != null) ...[
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'email'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'full_name'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'address'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'phone'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                if (_selectedOption?.extraFieldKey != null) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _extraController,
                    decoration: InputDecoration(
                      labelText: _selectedOption!.extraFieldKey!.tr(),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        _selectedOption!.icon,
                        color: _selectedOption!.color,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                RegistrationLegalConsent(
                  value: _acceptedLegal,
                  onChanged: (value) => setState(() => _acceptedLegal = value),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'registration'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildRoleTile(_RoleOption role) {
    final isSelected = selectedRole == role.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? role.color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (selectedRole != role.id) {
              _extraController.clear();
            }
            setState(() => selectedRole = role.id);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? role.color : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isSelected ? role.color : Colors.grey[200],
                  child: Icon(
                    role.icon,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    role.titleKey.tr(),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? role.color : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.info_outline, color: role.color),
                  onPressed: () => _showRoleInfo(role),
                  tooltip: 'role_info'.tr(),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: role.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
