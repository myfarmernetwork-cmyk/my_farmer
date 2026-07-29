import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../models/app_user.dart';
import '../../models/premium_access.dart';
import '../../models/product_units.dart';
import '../../utils/product_categories.dart';
import '../../utils/production_types.dart';
import '../../utils/upcoming_product_helper.dart';
import '../../services/product_upload_service.dart';
import '../../models/screen_guide_step.dart';
import '../../widgets/farmer_helper_button.dart';
import '../../widgets/premium_gate_dialog.dart';
import '../../providers/locale_settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/currency_service.dart';
import '../../services/firebase_storage_service.dart';
import '../../models/company_catalog_item.dart';
import '../../repositories/company_catalog_repository.dart';
import '../../widgets/barcode_scan_screen.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final Product? productToEdit;
  final CompanyCatalogItem? catalogPrefill;

  const AddProductScreen({
    super.key,
    this.productToEdit,
    this.catalogPrefill,
  });

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuCodeController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '999');
  final _unitDescriptionController = TextEditingController();

  File? _imageFile;
  final _picker = ImagePicker();
  bool _isUploading = false;
  final FirebaseStorageService _storageService = FirebaseStorageService();

  String _selectedCategory = ProductCategories.vegetables;
  String? _selectedSubTag;
  List<String> _searchTags = [];
  bool _isClassifyingImage = false;
  String _productionType = ProductionTypes.conventional;
  bool _isService = false;
  String _selectedUnit = 'kom';
  String _servicePriceUnit = 'dunum';
  String _existingImageUrl = '';
  String? _userRole;
  String? _subscriptionTier;
  int _existingProductCount = 0;
  bool _loadingLimits = true;
  bool _isUpcoming = false;
  DateTime _harvestDateTime =
      DateTime.now().add(const Duration(days: 7));

  final GlobalKey _guideNameKey = GlobalKey();
  final GlobalKey _guidePriceKey = GlobalKey();
  final GlobalKey _guideStockKey = GlobalKey();
  final GlobalKey _guideUpcomingKey = GlobalKey();

  List<ScreenGuideStep> get _guideSteps => [
        ScreenGuideStep(
          targetKey: _guideNameKey,
          titleKey: 'guide_product_name_title',
          bodyKey: 'guide_product_name_body',
        ),
        ScreenGuideStep(
          targetKey: _guidePriceKey,
          titleKey: 'guide_product_price_title',
          bodyKey: 'guide_product_price_body',
        ),
        ScreenGuideStep(
          targetKey: _guideStockKey,
          titleKey: 'guide_product_stock_title',
          bodyKey: 'guide_product_stock_body',
        ),
        ScreenGuideStep(
          targetKey: _guideUpcomingKey,
          titleKey: 'guide_product_upcoming_title',
          bodyKey: 'guide_product_upcoming_body',
        ),
      ];

  bool get _isEditing => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    final product = widget.productToEdit;
    if (product != null) {
      _nameController.text = product.name;
      _descriptionController.text = product.description;
      _priceController.text = product.price.toString();
      _selectedCategory = product.category;
      _selectedSubTag = product.subCategory;
      _searchTags = List<String>.from(product.searchTags);
      _productionType = ProductionTypes.normalize(product.productionType);
      _isService = product.isService;
      _selectedUnit = ProductUnits.normalize(product.unit);
      if (!ProductUnits.productUnits.contains(_selectedUnit)) {
        _selectedUnit = 'kom';
      }
      _servicePriceUnit =
          product.servicePriceUnit.isNotEmpty ? product.servicePriceUnit : 'dunum';
      _existingImageUrl = product.imageUrl;
      _stockController.text = product.stock.toString();
      _unitDescriptionController.text = product.unitDescription;
      _skuCodeController.text = product.skuCode ?? '';
      _productDescriptionController.text = product.productDescription ?? '';
      _isUpcoming = product.isUpcoming;
      if (product.harvestDateTime != null) {
        _harvestDateTime = product.harvestDateTime!;
      }
    } else {
      _applyCatalogPrefill(widget.catalogPrefill);
    }
    _loadUserLimits();
  }

  void _applyCatalogPrefill(CompanyCatalogItem? item) {
    if (item == null) return;
    _skuCodeController.text = item.skuCode;
    _nameController.text = item.name;
    _priceController.text = item.price.toStringAsFixed(2);
    _stockController.text = item.stock.toStringAsFixed(0);
    _selectedUnit = ProductUnits.normalize(item.unit);
    _selectedCategory = item.category;
    _productDescriptionController.text = item.productDescription.isNotEmpty
        ? item.productDescription
        : item.name;
    _searchTags = ProductUploadService.buildSearchTags(
      role: _userRole ?? 'pharmacy',
      categoryId: item.category,
    );
  }

  Future<void> _loadUserLimits() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    final data = userDoc.data() ?? {};
    final role = AppUser.normalizeRoleAlias(data['role']?.toString());

    final products = await FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: user.uid)
        .where('isService', isEqualTo: false)
        .get();

      if (mounted) {
        final defaultDays = UpcomingProductHelper.defaultLeadDays(role);
        final categoryCodes = ProductUploadService.categoryCodesForRole(role);
        setState(() {
          _userRole = role;
          _subscriptionTier = data['subscriptionTier'] as String?;
          _existingProductCount = products.docs.length;
          _loadingLimits = false;
          if (!categoryCodes.contains(_selectedCategory)) {
            _selectedCategory = categoryCodes.first;
            _selectedSubTag = null;
          } else if (UpcomingProductHelper.isCompanyRole(role)) {
            _selectedCategory =
                ProductUploadService.normalizeCompanyCategory(_selectedCategory);
          } else if (!ProductCategories.sellerCodes.contains(_selectedCategory)) {
            _selectedCategory = ProductCategories.vegetables;
          }
          if (!_isEditing && !_isUpcoming) {
            _harvestDateTime =
                DateTime.now().add(Duration(days: defaultDays));
          }
        });
      }
  }

  int get _maxProducts {
    final user = AppUser(
      uid: '',
      email: '',
      name: '',
      role: AppUser.parseRole(_userRole),
      subscriptionTier: _subscriptionTier,
    );
    return ProductUploadService.maxActiveProducts(user);
  }

  bool get _canAddService {
    if (_userRole == 'hobby_farmer') return false;
    final access = ref.read(premiumAccessProvider);
    return access.canUse(PremiumFeature.services);
  }

  bool get _canUseUpcomingHarvest {
    return UpcomingProductHelper.canUseUpcoming(
      role: _userRole,
      isPremium: ref.watch(isPremiumProvider).value ?? false,
    );
  }

  bool get _isCompanyRole => UpcomingProductHelper.isCompanyRole(_userRole);

  int get _upcomingMaxDays =>
      UpcomingProductHelper.maxLeadDaysForRole(_userRole);

  int get _upcomingDefaultDays =>
      UpcomingProductHelper.defaultLeadDays(_userRole);

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _skuCodeController.dispose();
    _productDescriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _unitDescriptionController.dispose();
    super.dispose();
  }

  Future<Position?> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      print("GPS greška: $e");
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() => _imageFile = file);
      _classifyImageInBackground(file);
    }
  }

  Future<void> _scanSkuBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );

    if (!mounted || code == null || code.trim().isEmpty) return;

    final trimmed = code.trim();
    setState(() => _skuCodeController.text = trimmed);

    if (_isCompanyRole) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final match = await ref
            .read(companyCatalogRepositoryProvider)
            .findBySku(sellerId: user.uid, skuCode: trimmed);
        if (match != null && mounted) {
          setState(() => _applyCatalogPrefill(match));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('company_catalog_barcode_found'.tr()),
              backgroundColor: Colors.green.shade700,
            ),
          );
          return;
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'add_product_barcode_scanned'.tr(namedArgs: {'code': trimmed}),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<void> _classifyImageInBackground(File file) async {
    if (!mounted) return;
    setState(() => _isClassifyingImage = true);
    try {
      final analysis = await ProductUploadService.analyzeProductFromImage(
        imageFile: file,
        role: _userRole,
        languageCode: context.locale.languageCode,
      );
      if (!mounted || analysis == null) return;

      final match = analysis.categoryMatch;

      setState(() {
        _selectedCategory = match.categoryId;
        _selectedSubTag = match.subTagId;
        _searchTags = ProductUploadService.buildSearchTags(
          role: _userRole,
          categoryId: match.categoryId,
          subTagId: match.subTagId,
          aiTags: match.searchTags,
        );

        final suggestedName = analysis.suggestedName?.trim();
        if (suggestedName != null && suggestedName.isNotEmpty) {
          _nameController.text = suggestedName;
        }

        final suggestedDescription = analysis.suggestedDescription?.trim();
        if (suggestedDescription != null && suggestedDescription.isNotEmpty) {
          if (_isCompanyRole) {
            _productDescriptionController.text = suggestedDescription;
          } else {
            _descriptionController.text = suggestedDescription;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('add_product_ai_category_detected'.tr()),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (_) {
      // Pozadinska AI klasifikacija — tiho ignoriraj greške.
    } finally {
      if (mounted) setState(() => _isClassifyingImage = false);
    }
  }

  void _showServiceInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('service_info_title'.tr()),
        content: Text('service_info_text'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildPackContentsField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade400, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shopping_bag_outlined, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'add_product_pack_contents'.tr(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _unitDescriptionController,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'add_product_pack_contents_hint'.tr(),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading:
              const Icon(Icons.photo_camera, color: Colors.green),
              title: Text('scanner_camera'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
              const Icon(Icons.photo_library, color: Colors.green),
              title: Text('scanner_gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickHarvestDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _harvestDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: _upcomingMaxDays)),
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

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null && _existingImageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('add_product_image_required'.tr()),
        ),
      );
      return;
    }

    if (_isUpcoming && !_canUseUpcomingHarvest) {
      if (_isCompanyRole) {
        await CompanyPremiumGateDialog.showForCompany(
          context,
          ref,
          feature: PremiumFeature.marketplaceBoost,
          onUnlocked: () {},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('product_upcoming_pro_only'.tr()),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
      return;
    }

    if (_isUpcoming) {
      final maxDate =
          DateTime.now().add(Duration(days: _upcomingMaxDays));
      if (_harvestDateTime.isAfter(maxDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isCompanyRole
                  ? 'product_upcoming_company_max_days'.tr(
                      namedArgs: {'days': '$_upcomingMaxDays'},
                    )
                  : 'product_upcoming_farmer_max_days'.tr(
                      namedArgs: {'days': '$_upcomingMaxDays'},
                    ),
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        return;
      }
    }

    if (!_isEditing) {
      if (_isService && !_canAddService) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('product_limit_reached'.tr())),
        );
        return;
      }

      if (!_isService && _existingProductCount >= _maxProducts) {
        if (_isCompanyRole) {
          await CompanyPremiumGateDialog.showForCompany(
            context,
            ref,
            feature: PremiumFeature.marketplaceBoost,
            onUnlocked: () {},
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('product_limit_reached'.tr())),
          );
        }
        return;
      }
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final sellerName = userData['name'] ?? 'Farmer';
      final originalCurrency = _isEditing
          ? widget.productToEdit!.originalCurrency
          : CurrencyService().resolveSellerCurrencyCode(
              currencyRegion: userData['currencyRegion'] as String?,
              locale: context.locale,
            );

      Position? position = await _determinePosition();

      var imageUrl = _existingImageUrl;
      if (_imageFile != null) {
        final uploaded = await _storageService.uploadProductImage(_imageFile!);
        if (uploaded != null) imageUrl = uploaded;
      }

      final payload = {
        'sellerId': user.uid,
        'sellerName': sellerName,
        'name': _nameController.text.trim(),
        'description': _isCompanyRole
            ? _productDescriptionController.text.trim()
            : _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'originalCurrency': originalCurrency,
        'unit': _isService ? 'kom' : _selectedUnit,
        if (_isService) 'servicePriceUnit': _servicePriceUnit,
        'category': _selectedCategory,
        if (_isCompanyRole && _selectedSubTag != null)
          'subCategory': _selectedSubTag,
        if (_isCompanyRole)
          'searchTags': ProductUploadService.buildSearchTags(
            role: _userRole,
            categoryId: _selectedCategory,
            subTagId: _selectedSubTag,
            aiTags: _searchTags,
          ),
        if (_isCompanyRole) ...{
          'skuCode': _skuCodeController.text.trim(),
          'productDescription': _productDescriptionController.text.trim(),
        },
        'productionType': _productionType,
        'isService': _isService,
        'imageUrl': imageUrl,
        if (!_isService)
          'stock': double.tryParse(_stockController.text.trim()) ?? 999.0,
        if (!_isService && ProductUnits.isPak(_selectedUnit)) ...{
          'unitDescription': _unitDescriptionController.text.trim(),
        } else ...{
          'unitDescription': '',
        },
        if (position != null)
          'location': {
            'lat': position.latitude,
            'lng': position.longitude,
          },
        if (!_isEditing && !_isService && _isUpcoming && _canUseUpcomingHarvest) ...{
          'isUpcoming': true,
          'harvestDateTime': Timestamp.fromDate(_harvestDateTime),
          'upcomingMode': UpcomingProductHelper.modeForRole(_userRole),
          'requiresFinalPhoto': false,
        },
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productToEdit!.id)
            .update(payload);
      } else {
        await FirebaseFirestore.instance.collection('products').add({
          ...payload,
          'createdAt': Timestamp.now(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Proizvod uspješno ažuriran!'
                  : 'Proizvod uspješno objavljen!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common_error'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currencyRegionProvider);
    final currency = CurrencyService()
        .resolve(context.locale, currencyRegion: ref.read(currencyRegionProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Uredi proizvod' : 'Novi proizvod'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          FarmerHelperIconButton(guideSteps: _guideSteps),
        ],
      ),
      body: _isUploading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 16),
            Text('add_product_publishing'.tr()),
          ],
        ),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // SLIKA
            GestureDetector(
              onTap: _showImagePicker,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.green.withOpacity(0.5)),
                ),
                child: _imageFile == null && _existingImageUrl.isEmpty
                    ? Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo,
                        size: 50,
                        color: Colors.green[700]),
                    const SizedBox(height: 8),
                    const Text(
                      "Dodaj sliku proizvoda",
                      style: TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Kamera ili galerija",
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12),
                    ),
                  ],
                )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : Image.network(_existingImageUrl, fit: BoxFit.cover),
                ),
              ),
            ),
            if (_isClassifyingImage) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'add_product_ai_classifying'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            // NAZIV
            TextFormField(
              key: _guideNameKey,
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Naziv proizvoda",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.eco_outlined),
              ),
              validator: (val) =>
              val!.isEmpty ? "Unesite naziv" : null,
            ),
            const SizedBox(height: 12),

            if (_isCompanyRole) ...[
              TextFormField(
                controller: _skuCodeController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'add_product_sku_label'.tr(),
                  hintText: 'add_product_scan_barcode'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code_scanner_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt_outlined),
                    tooltip: 'add_product_scan_barcode'.tr(),
                    onPressed: _scanSkuBarcode,
                  ),
                ),
                validator: (val) {
                  if (!_isCompanyRole) return null;
                  if (val == null || val.trim().isEmpty) {
                    return 'add_product_sku_required'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _productDescriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'add_product_detailed_description_label'.tr(),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.fact_check_outlined),
                ),
                validator: (val) {
                  if (!_isCompanyRole) return null;
                  if (val == null || val.trim().isEmpty) {
                    return 'add_product_detailed_description_required'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ] else ...[
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'add_product_description_optional'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // KATEGORIJA
            DropdownButtonFormField<String>(
              value: ProductUploadService.categoryCodesForRole(_userRole)
                      .contains(_selectedCategory)
                  ? _selectedCategory
                  : ProductUploadService.categoryCodesForRole(_userRole).first,
              isExpanded: true,
              items: ProductUploadService.categoryCodesForRole(_userRole)
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(
                        ProductUploadService.categoryLabelForRole(
                          role: _userRole,
                          code: code,
                          languageCode: context.locale.languageCode,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() {
                _selectedCategory = val!;
                if (!ProductUploadService.requiresSubTag(
                  _userRole,
                  _selectedCategory,
                )) {
                  _selectedSubTag = null;
                } else {
                  _selectedSubTag ??= 'other_protection';
                }
              }),
              decoration: InputDecoration(
                labelText: 'add_product_category'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.category_outlined),
              ),
            ),
            if (ProductUploadService.requiresSubTag(
              _userRole,
              _selectedCategory,
            )) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedSubTag ??
                    ProductUploadService.companyCategories
                        .firstWhere((c) => c.id == 'plant_protection')
                        .subTags
                        .last
                        .id,
                isExpanded: true,
                items: ProductUploadService.companyCategories
                    .firstWhere((c) => c.id == 'plant_protection')
                    .subTags
                    .map(
                      (tag) => DropdownMenuItem(
                        value: tag.id,
                        child: Text(
                          ProductUploadService.companySubTagLabel(
                            'plant_protection',
                            tag.id,
                            context.locale.languageCode,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedSubTag = val),
                decoration: InputDecoration(
                  labelText: 'add_product_subcategory'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
              ),
            ],
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _productionType,
              isExpanded: true,
              items: [
                ProductionTypes.conventional,
                ProductionTypes.organic,
              ]
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(ProductionTypes.label(code)),
                    ),
                  )
                  .toList(),
              onChanged: (val) =>
                  setState(() => _productionType = val!),
              decoration: InputDecoration(
                labelText: 'add_product_production_type'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.nature_outlined),
              ),
            ),
            const SizedBox(height: 12),

            if (_canAddService && !_isEditing)
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('add_product_is_service'.tr()),
                      value: _isService,
                      onChanged: (val) => setState(() => _isService = val),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline, color: Colors.green[700]),
                    tooltip: 'service_info_title'.tr(),
                    onPressed: _showServiceInfoDialog,
                  ),
                ],
              ),

            if (_isService && _canAddService) ...[
              DropdownButtonFormField<String>(
                value: _servicePriceUnit,
                items: ProductUnits.servicePriceUnits
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Text(ProductUnits.dropdownLabel(u)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _servicePriceUnit = val);
                },
                decoration: InputDecoration(
                  labelText: 'add_product_service_unit'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.straighten_outlined),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (!_isService) ...[
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                items: ProductUnits.productUnits
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Text(ProductUnits.dropdownLabel(u)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _selectedUnit = val;
                    if (!ProductUnits.isPak(val)) {
                      _unitDescriptionController.clear();
                    }
                  });
                },
                decoration: InputDecoration(
                  labelText: 'add_product_unit'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: 12),
              if (ProductUnits.isPak(_selectedUnit)) ...[
                _buildPackContentsField(),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: _guideStockKey,
                controller: _stockController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _isCompanyRole
                      ? 'add_product_company_stock_label'.tr()
                      : 'add_product_stock'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  suffixText: _selectedUnit,
                  helperText: _isCompanyRole
                      ? null
                      : 'add_product_stock_hint'.tr(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'add_product_stock_required'.tr();
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed < 0) {
                    return 'add_product_stock_invalid'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],

            if (!_isEditing && !_isService && _canUseUpcomingHarvest) ...[
              SwitchListTile(
                key: _guideUpcomingKey,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _isCompanyRole
                      ? 'product_upcoming_company_toggle'.tr()
                      : 'product_upcoming_toggle'.tr(),
                ),
                subtitle: Text(
                  _isCompanyRole
                      ? 'product_upcoming_company_toggle_hint'.tr(
                          namedArgs: {'days': '$_upcomingMaxDays'},
                        )
                      : 'product_upcoming_toggle_hint'.tr(),
                ),
                value: _isUpcoming,
                activeThumbColor: Colors.orange.shade700,
                onChanged: (value) {
                  setState(() {
                    _isUpcoming = value;
                    if (value) {
                      _harvestDateTime = DateTime.now().add(
                        Duration(days: _upcomingDefaultDays),
                      );
                    }
                  });
                },
              ),
              if (_isUpcoming) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _isCompanyRole
                        ? 'delivery_date_label'.tr()
                        : 'harvest_date_label'.tr(),
                  ),
                  subtitle: Text(
                    '${_harvestDateTime.day}.${_harvestDateTime.month}.${_harvestDateTime.year} '
                    '${_harvestDateTime.hour.toString().padLeft(2, '0')}:'
                    '${_harvestDateTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: _pickHarvestDateTime,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // CIJENA
            TextFormField(
              key: _guidePriceKey,
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _isService
                    ? 'add_product_price_per_unit'.tr()
                    : _isCompanyRole
                        ? 'add_product_company_price_label'.tr()
                        : 'add_product_price'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money_outlined),
                suffixText: _isService
                    ? '${currency.symbol} / $_servicePriceUnit'
                    : '${currency.symbol} / $_selectedUnit',
              ),
              validator: (val) =>
              val!.isEmpty ? "Unesite cijenu" : null,
            ),
            const SizedBox(height: 30),

            // DUGME
            ElevatedButton(
              onPressed: _submitProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(
                _isEditing ? 'SPREMI IZMJENE' : 'OBJAVI NA PRODAVNICU',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}