import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/company_catalog_item.dart';
import '../../models/product.dart';
import '../../models/screen_guide_step.dart';
import '../../repositories/company_catalog_repository.dart';
import '../../services/company_catalog_csv_parser.dart';
import '../../services/currency_service.dart';
import '../../utils/firestore_error_helper.dart';
import '../../utils/scroll_bottom_padding.dart';
import '../../widgets/company_catalog_guide.dart';
import '../../widgets/firestore_error_panel.dart';
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
      // Android 9 (Motorola X4): withData:true često vrati null — čitamo s path/stream.
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final bytes = await _readPickedFileBytes(picked);
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('company_catalog_import_failed'.tr()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    setState(() => _importing = true);
    try {
      final text = CompanyCatalogCsvParser.stripBom(
        utf8.decode(bytes, allowMalformed: true),
      );
      final rows = CompanyCatalogCsvParser.parse(text);
      if (!mounted) return;

      final toImport = await _showImportPreviewSheet(rows);
      if (toImport == null || toImport.isEmpty || !mounted) return;

      final importResult = await ref
          .read(companyCatalogRepositoryProvider)
          .importRows(sellerId: user.uid, rows: toImport);
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

  Future<List<ParsedCatalogRow>?> _showImportPreviewSheet(
    List<ParsedCatalogRow> rows,
  ) {
    return showModalBottomSheet<List<ParsedCatalogRow>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CsvImportPreviewSheet(rows: rows),
    );
  }

  /// Na Androidu 9+ [PlatformFile.bytes] često je null — čitamo s diska ili streama.
  Future<List<int>?> _readPickedFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }

    final path = file.path;
    if (path != null && path.isNotEmpty) {
      try {
        return await File(path).readAsBytes();
      } catch (_) {
        // Nastavi na readStream (content:// URI na starijem Androidu).
      }
    }

    final stream = file.readStream;
    if (stream != null) {
      try {
        final chunks = await stream.toList();
        if (chunks.isEmpty) return null;
        return chunks.expand((chunk) => chunk).toList(growable: false);
      } catch (_) {
        return null;
      }
    }

    return null;
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

  Future<void> _openAddWithItem(CompanyCatalogItem item) async {
    if (item.isPublished && item.publishedProductId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(item.publishedProductId!)
            .get();
        if (!mounted) return;
        if (doc.exists) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddProductScreen(
                productToEdit: Product.fromFirestore(doc),
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // Nastavi na catalogPrefill ako proizvod nije učitán.
      }
    }

    if (!mounted) return;
    await Navigator.push(
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
          if (snapshot.hasError) {
            return FirestoreErrorPanel(error: snapshot.error!);
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];
          final hasCatalogItems = items.isNotEmpty;
          final hasPublishedItems = items.any((i) => i.isPublished);

          return ListView(
            padding: ScrollBottomPadding.list(
              context,
              base: const EdgeInsets.all(16),
            ),
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

class _CsvImportPreviewSheet extends StatefulWidget {
  const _CsvImportPreviewSheet({required this.rows});

  final List<ParsedCatalogRow> rows;

  @override
  State<_CsvImportPreviewSheet> createState() => _CsvImportPreviewSheetState();
}

class _CsvImportPreviewSheetState extends State<_CsvImportPreviewSheet> {
  late final Set<String> _selectedSkus;

  @override
  void initState() {
    super.initState();
    _selectedSkus = widget.rows.map((r) => r.skuCode).toSet();
  }

  bool get _allSelected => _selectedSkus.length == widget.rows.length;

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedSkus
          ..clear()
          ..addAll(widget.rows.map((r) => r.skuCode));
      } else {
        _selectedSkus.clear();
      }
    });
  }

  void _toggleRow(String sku, bool selected) {
    setState(() {
      if (selected) {
        _selectedSkus.add(sku);
      } else {
        _selectedSkus.remove(sku);
      }
    });
  }

  List<ParsedCatalogRow> _rowsForImport(bool all) {
    if (all) return widget.rows;
    return widget.rows
        .where((row) => _selectedSkus.contains(row.skuCode))
        .toList(growable: false);
  }

  void _import({required bool all}) {
    final rows = _rowsForImport(all);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('company_catalog_import_none_selected'.tr()),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }
    Navigator.pop(context, rows);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'company_catalog_import_preview_title'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            CheckboxListTile(
              value: _allSelected ? true : (_selectedSkus.isEmpty ? false : null),
              tristate: true,
              onChanged: (value) {
                if (value == null) {
                  _toggleAll(true);
                } else {
                  _toggleAll(value);
                }
              },
              title: Text(
                'company_catalog_import_select_all'.tr(
                  namedArgs: {'count': '${widget.rows.length}'},
                ),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.rows.length,
                itemBuilder: (context, index) {
                  final row = widget.rows[index];
                  final selected = _selectedSkus.contains(row.skuCode);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (value) =>
                        _toggleRow(row.skuCode, value ?? false),
                    title: Text(
                      row.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${row.skuCode} · ${row.price.toStringAsFixed(2)} · '
                      '${row.stock.toStringAsFixed(0)} ${row.unit}',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _import(all: false),
                      child: Text('company_catalog_import_selected_btn'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _import(all: true),
                      child: Text('company_catalog_import_all_btn'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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