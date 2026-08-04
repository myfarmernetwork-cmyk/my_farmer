import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../services/firebase_storage_service.dart';
import '../../utils/harvest_formatter.dart';
import '../../utils/upcoming_product_helper.dart';

class ManageHarvestScreen extends ConsumerStatefulWidget {
  const ManageHarvestScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ManageHarvestScreen> createState() =>
      _ManageHarvestScreenState();
}

class _ManageHarvestScreenState extends ConsumerState<ManageHarvestScreen> {
  final _storageService = FirebaseStorageService();
  final _picker = ImagePicker();

  late DateTime _harvestDateTime;
  File? _developmentImage;
  File? _finalImage;
  bool _isSaving = false;

  Product get product => widget.product;

  bool get _isDelivery =>
      UpcomingProductHelper.isDeliveryMode(product.upcomingMode);

  int get _maxLeadDays =>
      UpcomingProductHelper.maxLeadDaysForMode(product.upcomingMode);

  @override
  void initState() {
    super.initState();
    _harvestDateTime = product.harvestDateTime ??
        DateTime.now().add(const Duration(days: 7));
  }

  Future<void> _pickImage({required bool isFinal}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFinal) {
        _finalImage = File(picked.path);
      } else {
        _developmentImage = File(picked.path);
      }
    });
  }

  Future<void> _pickHarvestDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _harvestDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: _maxLeadDays)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_harvestDateTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _harvestDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);
    try {
      String? imageUrl;
      if (_developmentImage != null) {
        imageUrl = await _storageService.uploadProductImage(_developmentImage!);
      }

      await ref.read(productRepositoryProvider).updateHarvestSchedule(
            productId: product.id,
            harvestDateTime: _harvestDateTime,
            imageUrl: imageUrl,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('harvest_schedule_saved'.tr()),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _completeHarvest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('harvest_complete_confirm_title'.tr()),
        content: Text('harvest_complete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('harvest_complete_action'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(productRepositoryProvider).completeHarvest(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('harvest_complete_success'.tr())),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadFinalPhoto() async {
    if (_finalImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('harvest_final_photo_required'.tr())),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final imageUrl = await _storageService.uploadProductImage(_finalImage!);
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('harvest_final_photo_upload_failed');
      }

      await ref.read(productRepositoryProvider).publishFinalHarvestPhoto(
            productId: product.id,
            imageUrl: imageUrl,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('harvest_final_photo_success'.tr()),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final awaitingFinal = product.requiresFinalPhoto;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isDelivery ? 'delivery_manage_title'.tr() : 'harvest_manage_title'.tr(),
        ),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (awaitingFinal) _FinalPhotoBanner(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _developmentImage != null
                      ? Image.file(
                          _developmentImage!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : product.imageUrl.isNotEmpty
                          ? Image.network(
                              product.imageUrl,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 180,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image, size: 64),
                            ),
                ),
                const SizedBox(height: 16),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (awaitingFinal) ...[
                  Text(
                    _isDelivery
                        ? 'delivery_final_photo_instruction'.tr()
                        : 'harvest_final_photo_instruction'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _pickImage(isFinal: true),
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: _finalImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                _finalImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  size: 48,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(height: 8),
                                Text('harvest_final_photo_pick'.tr()),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _uploadFinalPhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: Text('harvest_publish_final_photo'.tr()),
                  ),
                ] else ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _isDelivery
                          ? 'delivery_date_label'.tr()
                          : 'harvest_date_label'.tr(),
                    ),
                    subtitle: Text(
                      HarvestFormatter.formatHarvestDate(_harvestDateTime),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: _pickHarvestDateTime,
                    ),
                  ),
                  if (product.isHarvestCountdownActive &&
                      product.harvestDateTime != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        HarvestFormatter.fullCountdownLine(
                          product.harvestDateTime!,
                          isDelivery: _isDelivery,
                        ),
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(isFinal: false),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text('harvest_update_development_photo'.tr()),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _saveSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: const Icon(Icons.save),
                    label: Text('harvest_save_schedule'.tr()),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _completeHarvest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: const Icon(Icons.agriculture),
                    label: Text('harvest_complete_action'.tr()),
                  ),
                ],
              ],
            ),
      ),
    );
  }
}

class _FinalPhotoBanner extends StatefulWidget {
  @override
  State<_FinalPhotoBanner> createState() => _FinalPhotoBannerState();
}

class _FinalPhotoBannerState extends State<_FinalPhotoBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(_controller),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'harvest_final_photo_alert'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
