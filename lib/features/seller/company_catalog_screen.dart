import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/company_catalog_item.dart';
import '../../models/screen_guide_step.dart';
import '../../repositories/company_catalog_repository.dart';
import '../../services/company_catalog_csv_parser.dart';
import '../../services/currency_service.dart';
import '../../widgets/company_catalog_guide.dart';
import '../../widgets/farmer_screen_guide.dart';
import 'add_product_screen.dart';

/// Interni katalog firme — CSV import, checklist, vodič.
class CompanyCatalogScreen extends ConsumerStatefulWidget {
  const CompanyCatalogScreen({super.key});

  @override
  ConsumerState<CompanyCatalogScreen> createState() =>
      _CompanyCatalogScreenState();
}

class _CompanyCatalogScreenState extends ConsumerState<CompanyCatalogScreen> {
  bool _importing = false;
  String? _publishingItemId;
  bool _onboardingStarted = false;

  final _guideHowKey = GlobalKey();
  final _guideSetupKey = GlobalKey();
  final _guideSampleKey = GlobalKey();
  final _guideImportKey = GlobalKey();
  final _guideListKey = GlobalKey();

  List<ScreenGuideStep> get _guideSteps => companyCatalogGuideSteps(
        howItWorksKey: _guideHowKey,
        setupKey: _guideSetupKey,
        sampleKey: _guideSampleKey,
        importKey: _guideImportKey,
        listKey: _guideListKey,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runOnboarding());
  }

  Future<void> _runOnboarding() async {
    if (_onboardingStarted || !mounted) return;
    _onboardingStarted = true;

    final startGuide = await CompanyCatalogWelcomeDialog.showIfNeeded(context);
    if (!mounted) return;
    if (startGuide == true) {
      await showCompanyCatalogSpotlightIfNeeded(context, _guideSteps);
    }
  }

  void _openGuide() {
    FarmerScreenGuide.show(context, _guideSteps, ignoreRoleGate: true);
  }

  Future<void> _importCsv() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) return;

    setState(() => _importing = true);
    try {
      final text = CompanyCatalogCsvParser.stripBom(
        utf8.decode(bytes, allowMalformed: true),
      );
      final importResult = await ref
          .read(companyCatalogRepositoryProvider)
          .importCsv(sellerId: user.uid, csvContent: text);
      if (!mounted) return;

      final message = importResult.updated > 0
          ? 'company_catalog_import_success_detail'.tr(
              namedArgs: {
                'count': '${importResult.total}',
                'inserted': '${importResult.inserted}',
                'updated': '${importResult.updated}',
              },
            )
          : 'company_catalog_import_success'.tr(
              namedArgs: {'count': '${importResult.total}'},
            );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on CompanyCatalogCsvParseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.messageKey.tr(namedArgs: e.namedArgs)),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('company_catalog_import_failed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _publishItem(CompanyCatalogItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _publishingItemId = item.id);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data() ?? {};
      final sellerName = data['name'] as String? ?? 'Firma';
      final currency = CurrencyService().resolveSellerCurrencyCode(
        currencyRegion: data['currencyRegion'] as String?,
        locale: context.locale,
      );

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {}

      await ref.read(companyCatalogRepositoryProvider).publishToMarketplace(
            item: item,
            sellerName: sellerName,
            originalCurrency: currency,
            lat: position?.latitude,
            lng: position?.longitude,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.isPublished
                ? 'company_catalog_updated'.tr()
                : 'company_catalog_published'.tr(),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('company_catalog_publish_failed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _publishingItemId = null);
    }
  }

  void _openAddWithItem(CompanyCatalogItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(catalogPrefill: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('company_catalog_title'.tr())),
        body: Center(child: Text('company_catalog_login_required'.tr())),
      );
    }

    final itemsAsync = ref
        .watch(companyCatalogRepositoryProvider)
        .watchItems(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: Text('company_catalog_title'.tr()),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        actions: [
          const CompanyCatalogPdfGuideButton(),
          CompanyCatalogGuideButton(guideSteps: _guideSteps),
        ],
      ),
      body: StreamBuilder<List<CompanyCatalogItem>>(
        stream: itemsAsync,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          final hasCatalogItems = items.isNotEmpty;
          final hasPublishedItems = items.any((i) => i.isPublished);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CompanyCatalogHowItWorks(guideKey: _guideHowKey),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: _guideSetupKey,
                child: CompanySetupChecklist(
                  hasCatalogItems: hasCatalogItems,
                  hasPublishedItems: hasPublishedItems,
                  onOpenGuide: _openGuide,
                ),
              ),
              const SizedBox(height: 12),
              CompanyCatalogSampleCsv(guideKey: _guideSampleKey),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: _guideImportKey,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'company_catalog_help_title'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'company_catalog_help_body'.tr(),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _importing ? null : _importCsv,
                            icon: _importing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.upload_file),
                            label: Text('company_catalog_import_btn'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'company_catalog_empty'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else ...[
                if (items.where((i) => !i.isPublished).isNotEmpty ||
                    items.where((i) => i.isLowStock).isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (items.where((i) => !i.isPublished).isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.storefront, size: 18),
                          label: Text(
                            'company_catalog_unpublished'.tr(
                              namedArgs: {
                                'count':
                                    '${items.where((i) => !i.isPublished).length}',
                              },
                            ),
                          ),
                        ),
                      if (items.where((i) => i.isLowStock).isNotEmpty)
                        Chip(
                          avatar: Icon(
                            Icons.warning_amber,
                            size: 18,
                            color: Colors.orange.shade800,
                          ),
                          label: Text(
                            'company_catalog_low_stock'.tr(
                              namedArgs: {
                                'count':
                                    '${items.where((i) => i.isLowStock).length}',
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: _guideListKey,
                  child: Column(
                    children: [
                      for (final item in items) ...[
                        _CatalogItemTile(
                          item: item,
                          publishing: _publishingItemId == item.id,
                          onPublish: () => _publishItem(item),
                          onEdit: () => _openAddWithItem(item),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CatalogItemTile extends StatelessWidget {
  const _CatalogItemTile({
    required this.item,
    required this.publishing,
    required this.onPublish,
    required this.onEdit,
  });

  final CompanyCatalogItem item;
  final bool publishing;
  final VoidCallback onPublish;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${item.skuCode}'),
            Text(
              '${item.price.toStringAsFixed(2)} · '
              '${'company_catalog_stock'.tr(namedArgs: {
                    'stock': item.stock.toStringAsFixed(0),
                  })}',
            ),
          ],
        ),
        isThreeLine: true,
        trailing: publishing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'publish') onPublish();
                  if (value == 'edit') onEdit();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'publish',
                    child: Text(
                      item.isPublished
                          ? 'company_catalog_sync_shop'.tr()
                          : 'company_catalog_publish_btn'.tr(),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('company_catalog_edit_btn'.tr()),
                  ),
                ],
              ),
        leading: CircleAvatar(
          backgroundColor: item.isPublished
              ? Colors.green.shade50
              : Colors.grey.shade100,
          child: Icon(
            item.isPublished ? Icons.check_circle : Icons.inventory_2_outlined,
            color: item.isPublished
                ? Colors.green.shade700
                : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}