import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/premium_access.dart';
import '../../models/vet_field_report.dart';
import '../../providers/subscription_provider.dart';
import '../../repositories/vet_field_report_repository.dart';
import '../../repositories/veterinary_request_repository.dart';
import '../../widgets/farmer_help_widgets.dart';

/// Tab „Terenski nalazi“ u kartoteci pacijenata veterinara.
class VeterinarFieldReportsTab extends ConsumerWidget {
  const VeterinarFieldReportsTab({super.key});

  static bool canManageReports(WidgetRef ref) {
    final access = ref.read(premiumAccessProvider);
    return ref.read(adminPremiumBypassProvider) ||
        access.canUse(PremiumFeature.digitalMedicalIntake);
  }

  static void openAddForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _AddFieldReportSheet(
        parentRef: ref,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(vetFieldReportsProvider);

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('common_error'.tr(namedArgs: {'error': '$error'})),
      ),
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.terrain_outlined,
                      size: 72, color: Colors.teal.shade300),
                  const SizedBox(height: 20),
                  Text(
                    farmerGuideTr(context, 'vet_animals_field_findings'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    farmerGuideTr(context, 'vet_field_report_empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return _FieldReportCard(report: report);
          },
        );
      },
    );
  }
}

class _FieldReportCard extends StatelessWidget {
  const _FieldReportCard({required this.report});

  final VetFieldReport report;

  String _formatDate(BuildContext context) {
    final createdAt = report.createdAt;
    if (createdAt == null) return '';
    return DateFormat.yMMMd(context.locale.toString()).add_Hm().format(createdAt);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  child: Icon(Icons.assignment_outlined,
                      color: Colors.teal.shade800),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.farmerName,
                        style: TextStyle(
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_formatDate(context).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (report.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                report.notes,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ],
            if (report.photoUrl != null && report.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  report.photoUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.grey.shade500),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddFieldReportSheet extends ConsumerStatefulWidget {
  const _AddFieldReportSheet({required this.parentRef});

  final WidgetRef parentRef;

  @override
  ConsumerState<_AddFieldReportSheet> createState() =>
      _AddFieldReportSheetState();
}

class _AddFieldReportSheetState extends ConsumerState<_AddFieldReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _customFarmerController = TextEditingController();
  final _picker = ImagePicker();

  String? _selectedFarmerId;
  String? _selectedFarmerName;
  bool _useCustomFarmer = false;
  File? _photoFile;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _customFarmerController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> _farmerOptions() {
    final requests =
        widget.parentRef.read(vetIncomingRequestsProvider).valueOrNull ?? [];
    final map = <String, String>{};
    for (final request in requests) {
      if (request.clientId.isEmpty) continue;
      map[request.clientId] = request.clientName;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() => _photoFile = File(picked.path));
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(farmerGuideTr(context, 'vet_field_report_photo_camera')),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(farmerGuideTr(context, 'vet_field_report_photo_gallery')),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final farmers = _farmerOptions();
    final useCustom = farmers.isEmpty || _useCustomFarmer;
    final farmerName = useCustom
        ? _customFarmerController.text.trim()
        : (_selectedFarmerName ?? '').trim();
    final farmerId = useCustom
        ? 'manual_${DateTime.now().millisecondsSinceEpoch}'
        : (_selectedFarmerId ?? '').trim();

    if (farmerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(farmerGuideTr(context, 'vet_field_report_farmer_required')),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(vetFieldReportRepositoryProvider);
      String? photoUrl;
      if (_photoFile != null) {
        photoUrl = await repo.uploadPhoto(
          imageFile: _photoFile!,
          vetId: user.uid,
        );
      }

      await repo.createReport(
        title: _titleController.text.trim(),
        farmerId: farmerId,
        farmerName: farmerName,
        notes: _notesController.text.trim(),
        photoUrl: photoUrl,
        vetName: user.displayName,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(farmerGuideTr(context, 'vet_field_report_saved')),
          backgroundColor: Colors.teal.shade800,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common_error'.tr(namedArgs: {'error': '$error'}))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmers = _farmerOptions();
    final showDropdown = farmers.isNotEmpty && !_useCustomFarmer;
    final showCustomField = farmers.isEmpty || _useCustomFarmer;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      farmerGuideTr(context, 'vet_field_report_add'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: farmerGuideTr(context, 'vet_field_report_title_label'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return farmerGuideTr(context, 'vet_field_report_title_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Text(
                farmerGuideTr(context, 'vet_field_report_farmer_label'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              if (showDropdown)
                DropdownButtonFormField<String>(
                  value: _selectedFarmerId,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: farmerGuideTr(
                      context,
                      'vet_field_report_select_farmer',
                    ),
                  ),
                  hint: Text(
                    farmerGuideTr(context, 'vet_field_report_select_farmer'),
                  ),
                  items: [
                    ...farmers.map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFarmerId = value;
                      _selectedFarmerName = farmers
                          .firstWhere((e) => e.key == value,
                              orElse: () => const MapEntry('', ''))
                          .value;
                    });
                  },
                  validator: (value) {
                    if (!showDropdown) return null;
                    if (value == null || value.isEmpty) {
                      return farmerGuideTr(
                        context,
                        'vet_field_report_farmer_required',
                      );
                    }
                    return null;
                  },
                )
              else if (showCustomField)
                TextFormField(
                  controller: _customFarmerController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: farmers.isEmpty
                        ? farmerGuideTr(context, 'vet_field_report_farmer_label')
                        : farmerGuideTr(context, 'vet_field_report_other_farmer'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!showCustomField) return null;
                    if (value == null || value.trim().isEmpty) {
                      return farmerGuideTr(
                        context,
                        'vet_field_report_farmer_required',
                      );
                    }
                    return null;
                  },
                ),
              if (farmers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _useCustomFarmer = !_useCustomFarmer;
                        _selectedFarmerId = null;
                        _selectedFarmerName = null;
                        _customFarmerController.clear();
                      });
                    },
                    child: Text(
                      _useCustomFarmer
                          ? farmerGuideTr(context, 'vet_field_report_select_farmer')
                          : farmerGuideTr(context, 'vet_field_report_other_farmer'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: farmerGuideTr(context, 'vet_field_report_notes_label'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _saving ? null : _showPhotoOptions,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(farmerGuideTr(context, 'vet_field_report_photo_btn')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal.shade800,
                  side: BorderSide(color: Colors.teal.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_photoFile != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _photoFile!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(farmerGuideTr(context, 'vet_field_report_save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
