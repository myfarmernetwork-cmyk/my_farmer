import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/animal_record.dart';
import '../models/medical_history_entry.dart';
import '../models/screen_guide_step.dart';
import '../features/vet/veterinar_field_reports_tab.dart';
import '../models/veterinary_request.dart';
import '../models/vet_conversation_message.dart';
import '../providers/subscription_provider.dart';
import '../repositories/animal_repository.dart';
import '../repositories/veterinary_request_repository.dart';
import '../widgets/farmer_helper_button.dart';
import '../widgets/farmer_help_widgets.dart';
import '../widgets/medical_attachment_viewer.dart';
import '../widgets/vet_first_aid_dialog.dart';

const _animalsListPageSize = 25;

class MyAnimalsScreen extends ConsumerStatefulWidget {
  const MyAnimalsScreen({super.key});

  @override
  ConsumerState<MyAnimalsScreen> createState() => _MyAnimalsScreenState();
}

class _MyAnimalsScreenState extends ConsumerState<MyAnimalsScreen> {
  final GlobalKey _guideListKey = GlobalKey();
  final GlobalKey _guideRecordsKey = GlobalKey();
  final GlobalKey _addAnimalKey = GlobalKey();
  final ScrollController _listScrollController = ScrollController();
  int _currentPage = 0;

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  void _goToPage(int page, int totalPages) {
    if (totalPages <= 0) return;
    setState(() => _currentPage = page.clamp(0, totalPages - 1));
    if (_listScrollController.hasClients) {
      _listScrollController.jumpTo(0);
    }
  }

  Widget _buildPaginationBar(
    BuildContext context, {
    required int currentPage,
    required int totalPages,
    required int rangeStart,
    required int rangeEnd,
    required int totalItems,
  }) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Material(
      elevation: 4,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: farmerGuideTr(
                  context,
                  'vet_intake_prev_page',
                  fallbacks: const {
                    'hr': 'Prethodna stranica',
                    'bs': 'Prethodna stranica',
                    'sr': 'Prethodna stranica',
                    'de': 'Vorherige Seite',
                    'en': 'Previous page',
                  },
                ),
                onPressed: currentPage > 0
                    ? () => _goToPage(currentPage - 1, totalPages)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      farmerGuideTr(
                        context,
                        'vet_intake_page',
                        fallbacks: const {
                          'hr': 'Stranica {current} od {total}',
                          'bs': 'Stranica {current} od {total}',
                          'sr': 'Stranica {current} od {total}',
                          'de': 'Seite {current} von {total}',
                          'en': 'Page {current} of {total}',
                        },
                      )
                          .replaceAll('{current}', '${currentPage + 1}')
                          .replaceAll('{total}', '$totalPages'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade900,
                      ),
                    ),
                    Text(
                      farmerGuideTr(
                        context,
                        'vet_intake_page_range',
                        fallbacks: const {
                          'hr': '{from}–{to} od {total}',
                          'bs': '{from}–{to} od {total}',
                          'sr': '{from}–{to} od {total}',
                          'de': '{from}–{to} von {total}',
                          'en': '{from}–{to} of {total}',
                        },
                      )
                          .replaceAll('{from}', '$rangeStart')
                          .replaceAll('{to}', '$rangeEnd')
                          .replaceAll('{total}', '$totalItems'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: farmerGuideTr(
                  context,
                  'vet_intake_next_page',
                  fallbacks: const {
                    'hr': 'Sljedeća stranica',
                    'bs': 'Sljedeća stranica',
                    'sr': 'Sledeća stranica',
                    'de': 'Nächste Seite',
                    'en': 'Next page',
                  },
                ),
                onPressed: currentPage < totalPages - 1
                    ? () => _goToPage(currentPage + 1, totalPages)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ScreenGuideStep> get _guideSteps => [
        ScreenGuideStep(
          targetKey: _guideListKey,
          titleKey: 'guide_animals_list_title',
          bodyKey: 'guide_animals_list_body',
        ),
        ScreenGuideStep(
          targetKey: _guideRecordsKey,
          titleKey: 'guide_animals_records_title',
          bodyKey: 'guide_animals_records_body',
        ),
        ScreenGuideStep(
          targetKey: _addAnimalKey,
          titleKey: 'guide_animals_add_title',
          bodyKey: 'guide_animals_add_body',
          highlightPadding: const EdgeInsets.fromLTRB(6, 8, 6, 20),
          highlightLabelKey: 'animals_add',
        ),
      ];

  void _tryAddAnimal(BuildContext context, List<AnimalRecord> animals) {
    final access = ref.read(premiumAccessProvider);
    final max = access.maxAnimals;
    if (animals.length >= max) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            farmerGuideTr(
              context,
              'animals_limit_reached',
              fallbacks: {
                'hr': 'Dosegnut limit životinja za vaš paket ($max).',
                'de': 'Tierlimit für Ihr Paket erreicht ($max).',
                'en': 'Animal limit reached for your plan ($max).',
              },
            ),
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }
    _openEditor(context);
  }

  void _openEditor(BuildContext context, {AnimalRecord? animal}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimalEditorScreen(animal: animal),
      ),
    );
  }

  void _openDetails(BuildContext context, AnimalRecord animal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimalDetailScreen(animal: animal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animalsAsync = ref.watch(userAnimalsProvider);

    return Scaffold(
      key: ValueKey('my_animals_${context.locale}'),
      appBar: AppBar(
        title: Text('animals_title'.tr()),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          FarmerHelperIconButton(guideSteps: _guideSteps),
        ],
      ),
      floatingActionButton: animalsAsync.maybeWhen(
        data: (animals) => FloatingActionButton.extended(
          key: _addAnimalKey,
          onPressed: () => _tryAddAnimal(context, animals),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          elevation: 8,
          icon: const Icon(Icons.add),
          label: Text('animals_add'.tr()),
        ),
        orElse: () => FloatingActionButton.extended(
          key: _addAnimalKey,
          onPressed: () => _openEditor(context),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          elevation: 8,
          icon: const Icon(Icons.add),
          label: Text('animals_add'.tr()),
        ),
      ),
      body: SafeArea(
        top: false,
        child: animalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('common_error'.tr(namedArgs: {'error': '$error'})),
        ),
        data: (animals) {
          if (animals.isEmpty) {
            return KeyedSubtree(
              key: _guideListKey,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pets, size: 72, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'animals_empty'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      KeyedSubtree(
                        key: _guideRecordsKey,
                        child: Text(
                          'animals_empty_hint'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final totalCount = animals.length;
          final totalPages = totalCount == 0
              ? 0
              : (totalCount + _animalsListPageSize - 1) ~/ _animalsListPageSize;
          final currentPage =
              totalPages == 0 ? 0 : _currentPage.clamp(0, totalPages - 1);
          if (currentPage != _currentPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _currentPage = currentPage);
            });
          }
          final pageStart = currentPage * _animalsListPageSize;
          final pageEnd =
              (pageStart + _animalsListPageSize).clamp(0, totalCount);
          final pageItems = animals.sublist(pageStart, pageEnd);

          return KeyedSubtree(
            key: _guideListKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _listScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    itemCount: pageItems.length,
                    itemBuilder: (context, index) {
                      final animal = pageItems[index];
                      final isFirstOnFirstPage =
                          currentPage == 0 && index == 0;
                      return Card(
                        key: isFirstOnFirstPage ? _guideRecordsKey : null,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: animal.imageUrl.isNotEmpty
                                ? Image.network(
                                    animal.imageUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _placeholderAvatar(),
                                  )
                                : _placeholderAvatar(),
                          ),
                          title: Text(
                            animal.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${AnimalRecord.speciesLabel(animal.species)} · ${animal.age}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDetails(context, animal),
                        ),
                      );
                    },
                  ),
                ),
                _buildPaginationBar(
                  context,
                  currentPage: currentPage,
                  totalPages: totalPages,
                  rangeStart: totalCount == 0 ? 0 : pageStart + 1,
                  rangeEnd: pageEnd,
                  totalItems: totalCount,
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _placeholderAvatar() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.green[50],
      child: Icon(Icons.pets, color: Colors.green[700]),
    );
  }
}

class AnimalDetailScreen extends ConsumerWidget {
  final AnimalRecord animal;

  const AnimalDetailScreen({super.key, required this.animal});

  Future<void> _showAddHistoryEntry(
    BuildContext context,
    WidgetRef ref,
    AnimalRecord animal,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddHistoryEntryDialog(
        animal: animal,
        onSaved: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('animals_history_saved'.tr())),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animals = ref.watch(userAnimalsProvider).valueOrNull ?? [];
    final current = animals.firstWhere(
      (a) => a.id == animal.id,
      orElse: () => animal,
    );
    final vetResponseAsync = ref.watch(animalVetResponseProvider(current.id));
    final answeredRequest = vetResponseAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimalEditorScreen(animal: current),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('animals_delete_title'.tr()),
                  content: Text('animals_delete_confirm'.tr()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('cart_cancel'.tr()),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text('animals_delete'.tr()),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              await ref.read(animalRepositoryProvider).deleteAnimal(current.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showVetFirstAidDialog(
          context: context,
          ref: ref,
          animal: current,
        ),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.medical_services_outlined),
        label: Text(farmerGuideTr(context, 'first_aid_button')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          if (answeredRequest != null) ...[
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.blue.shade300, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.medical_information_outlined,
                            color: Colors.blue.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            farmerGuideTr(
                              context,
                              'vet_owner_response_title',
                              fallbacks: const {
                                'hr': 'Nalaz i uputa veterinara:',
                                'de': 'Befund und Anweisung des Tierarztes:',
                                'en': 'Veterinarian report and instructions:',
                              },
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (answeredRequest.vetName.isNotEmpty &&
                        answeredRequest.sortedConversationMessages.length <= 1) ...[
                      const SizedBox(height: 6),
                      Text(
                        answeredRequest.vetName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (answeredRequest.sortedConversationMessages.length > 1)
                      ...answeredRequest.sortedConversationMessages.map(
                        (message) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.vetName.isNotEmpty)
                                Text(
                                  message.vetName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (message.sentAt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat.yMMMd(context.locale.toString())
                                      .add_Hm()
                                      .format(message.sentAt!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade400,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                message.text,
                                style: const TextStyle(fontSize: 15, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Text(
                        answeredRequest.vetResponse,
                        style: const TextStyle(fontSize: 15, height: 1.45),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (current.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                current.imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.pets, size: 80, color: Colors.green[300]),
            ),
          const SizedBox(height: 20),
          _detailRow('animals_name'.tr(), current.name),
          _detailRow('animals_species'.tr(), AnimalRecord.speciesLabel(current.species)),
          _detailRow('animals_age'.tr(), current.age),
          const SizedBox(height: 16),
          Text(
            'animals_medical_history'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (current.sortedMedicalHistory.isEmpty)
            Text(
              'animals_history_empty'.tr(),
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            ...current.sortedMedicalHistory.map(
              (entry) => _MedicalHistoryTile(entry: entry),
            ),
          if (current.medicalDocuments.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'animals_documents_section'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final doc in current.medicalDocuments)
                    MedicalAttachmentListTile(attachment: doc),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showAddHistoryEntry(context, ref, current),
            icon: const Icon(Icons.note_add_outlined),
            label: Text('animals_add_history'.tr()),
          ),
          const SizedBox(height: 20),
          Text(
            'animals_medical_notes'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Text(
              current.medicalNotes.isEmpty
                  ? 'animals_no_notes'.tr()
                  : current.medicalNotes,
              style: const TextStyle(height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              current.formatMedicalCard(),
              style: TextStyle(color: Colors.grey[800], height: 1.4),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddHistoryEntryDialog extends ConsumerStatefulWidget {
  const _AddHistoryEntryDialog({
    required this.animal,
    required this.onSaved,
  });

  final AnimalRecord animal;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddHistoryEntryDialog> createState() =>
      _AddHistoryEntryDialogState();
}

class _AddHistoryEntryDialogState extends ConsumerState<_AddHistoryEntryDialog> {
  final _noteController = TextEditingController();
  final _picker = ImagePicker();
  final _pendingFiles = <File>[];
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _pendingFiles.add(File(picked.path)));
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    setState(() => _pendingFiles.add(File(result.files.single.path!)));
  }

  void _removePendingFile(int index) {
    setState(() => _pendingFiles.removeAt(index));
  }

  Future<void> _save() async {
    final note = _noteController.text.trim();
    if (note.isEmpty && _pendingFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('animals_history_save_requires'.tr())),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(animalRepositoryProvider);
      final attachments = <MedicalAttachment>[];

      for (final file in _pendingFiles) {
        final uploaded = await repo.uploadMedicalAttachment(
          file: file,
          userId: user.uid,
          animalId: widget.animal.id,
        );
        if (uploaded == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('animals_upload_failed'.tr())),
            );
          }
          return;
        }
        attachments.add(uploaded);
      }

      await repo.addMedicalHistoryEntry(
        animalId: widget.animal.id,
        note: note,
        attachments: attachments,
      );

      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'animals_save_error'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildPendingPreview(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    final isPdf = name.toLowerCase().endsWith('.pdf');

    return InkWell(
      onTap: () => openPendingMedicalFile(context, file),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: isPdf
            ? Icon(Icons.picture_as_pdf, color: Colors.red[700], size: 32)
            : ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.file(file, fit: BoxFit.cover),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('animals_add_history'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _noteController,
              maxLines: 4,
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: 'animals_history_note'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _isSaving ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text('animals_add_image'.tr()),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : _pickPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text('animals_attachment_pdf'.tr()),
                ),
              ],
            ),
            if (_pendingFiles.isNotEmpty) ...[
              Text(
                'animals_attachments_count'.tr(
                  namedArgs: {'count': '${_pendingFiles.length}'},
                ),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < _pendingFiles.length; i++)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildPendingPreview(_pendingFiles[i]),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: InkWell(
                            onTap: _isSaving ? null : () => _removePendingFile(i),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text('cart_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('profile_save'.tr()),
        ),
      ],
    );
  }
}

class _MedicalHistoryTile extends StatelessWidget {
  final MedicalHistoryEntry entry;

  const _MedicalHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateLabel = entry.createdAt != null
        ? DateFormatHelper.formatTimestamp(entry.createdAt!)
        : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dateLabel.isNotEmpty)
            Text(
              dateLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange[900],
              ),
            ),
          const SizedBox(height: 6),
          if (entry.note.trim().isNotEmpty) Text(entry.note),
          if (entry.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...entry.attachments.map(
              (attachment) => MedicalAttachmentListTile(attachment: attachment),
            ),
          ],
        ],
      ),
    );
  }
}

class AnimalEditorScreen extends ConsumerStatefulWidget {
  final AnimalRecord? animal;

  const AnimalEditorScreen({super.key, this.animal});

  @override
  ConsumerState<AnimalEditorScreen> createState() => _AnimalEditorScreenState();
}

class _AnimalEditorScreenState extends ConsumerState<AnimalEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();

  final GlobalKey _guidePhotoKey = GlobalKey();
  final GlobalKey _guideIdentityKey = GlobalKey();
  final GlobalKey _guideHealthKey = GlobalKey();
  final GlobalKey _guideDocumentsKey = GlobalKey();
  final GlobalKey _guideSaveKey = GlobalKey();

  List<ScreenGuideStep> get _guideSteps => [
        ScreenGuideStep(
          targetKey: _guidePhotoKey,
          titleKey: 'guide_add_animal_photo_title',
          bodyKey: 'guide_add_animal_photo_body',
        ),
        ScreenGuideStep(
          targetKey: _guideIdentityKey,
          titleKey: 'guide_add_animal_identity_title',
          bodyKey: 'guide_add_animal_identity_body',
        ),
        ScreenGuideStep(
          targetKey: _guideHealthKey,
          titleKey: 'guide_add_animal_health_title',
          bodyKey: 'guide_add_animal_health_body',
        ),
        ScreenGuideStep(
          targetKey: _guideDocumentsKey,
          titleKey: 'guide_add_animal_documents_title',
          bodyKey: 'guide_add_animal_documents_body',
        ),
        ScreenGuideStep(
          targetKey: _guideSaveKey,
          titleKey: 'guide_add_animal_save_title',
          bodyKey: 'guide_add_animal_save_body',
          highlightPadding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        ),
      ];

  String _species = AnimalRecord.speciesCodes.first;
  File? _imageFile;
  String _existingImageUrl = '';
  bool _isSaving = false;
  final List<MedicalAttachment> _medicalDocuments = [];
  final List<File> _pendingDocumentFiles = [];

  bool get _isEditing => widget.animal != null;

  @override
  void initState() {
    super.initState();
    final animal = widget.animal;
    if (animal != null) {
      _nameController.text = animal.name;
      _ageController.text = animal.age;
      _notesController.text = animal.medicalNotes;
      _species = AnimalRecord.normalizeSpecies(animal.species);
      _existingImageUrl = animal.imageUrl;
      _medicalDocuments.addAll(animal.medicalDocuments);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('animals_photo_camera'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('animals_photo_gallery'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDocumentSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('animals_doc_take_photo'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _attachDocumentFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('animals_photo_gallery'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _attachDocumentFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text('animals_doc_pick_file'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _attachDocumentFromFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _attachDocumentFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    setState(() => _pendingDocumentFiles.add(File(picked.path)));
  }

  Future<void> _attachDocumentFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    setState(() => _pendingDocumentFiles.add(File(picked.path)));
  }

  Future<void> _attachDocumentFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    setState(() => _pendingDocumentFiles.add(File(result.files.single.path!)));
  }

  void _removeSavedDocument(int index) {
    setState(() => _medicalDocuments.removeAt(index));
  }

  void _removePendingDocument(int index) {
    setState(() => _pendingDocumentFiles.removeAt(index));
  }

  Future<List<MedicalAttachment>> _uploadPendingDocuments({
    required AnimalRepository repo,
    required String userId,
    required String animalId,
  }) async {
    final uploaded = <MedicalAttachment>[];
    for (final file in _pendingDocumentFiles) {
      final attachment = await repo.uploadMedicalAttachment(
        file: file,
        userId: userId,
        animalId: animalId,
      );
      if (attachment != null) uploaded.add(attachment);
    }
    return uploaded;
  }

  Widget _buildDocumentThumbnail({
    required String label,
    required Widget preview,
    required VoidCallback onRemove,
    VoidCallback? onOpen,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: preview,
                ),
              ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: InkWell(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachedDocumentsPreview() {
    if (_medicalDocuments.isEmpty && _pendingDocumentFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 18,
        children: [
          ...List.generate(_medicalDocuments.length, (index) {
            final doc = _medicalDocuments[index];
            final isPdf = doc.type == 'pdf';
            return _buildDocumentThumbnail(
              label: doc.name.isEmpty ? 'PDF' : doc.name,
              preview: isPdf
                  ? Icon(Icons.picture_as_pdf, color: Colors.red[700], size: 36)
                  : Image.network(doc.url, fit: BoxFit.cover),
              onRemove: () => _removeSavedDocument(index),
              onOpen: () => openMedicalAttachment(context, doc),
            );
          }),
          ...List.generate(_pendingDocumentFiles.length, (index) {
            final file = _pendingDocumentFiles[index];
            final name = file.path.split(Platform.pathSeparator).last;
            final isPdf = name.toLowerCase().endsWith('.pdf');
            return _buildDocumentThumbnail(
              label: name,
              preview: isPdf
                  ? Icon(Icons.picture_as_pdf, color: Colors.red[700], size: 36)
                  : Image.file(file, fit: BoxFit.cover),
              onRemove: () => _removePendingDocument(index),
              onOpen: () => openPendingMedicalFile(context, file),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(animalRepositoryProvider);
      var imageUrl = _existingImageUrl;

      if (_imageFile != null) {
        final uploaded = await repo.uploadAnimalImage(_imageFile!, user.uid);
        if (uploaded != null) imageUrl = uploaded;
      }

      final documents = List<MedicalAttachment>.from(_medicalDocuments);

      if (_isEditing) {
        if (_pendingDocumentFiles.isNotEmpty) {
          final uploadedDocs = await _uploadPendingDocuments(
            repo: repo,
            userId: user.uid,
            animalId: widget.animal!.id,
          );
          documents.addAll(uploadedDocs);
        }
        await repo.updateAnimal(
          widget.animal!.copyWith(
            name: _nameController.text.trim(),
            species: _species,
            age: _ageController.text.trim(),
            medicalNotes: _notesController.text.trim(),
            imageUrl: imageUrl,
            medicalDocuments: documents,
          ),
        );
      } else {
        final created = await repo.createAnimal(
          name: _nameController.text.trim(),
          species: _species,
          age: _ageController.text.trim(),
          medicalNotes: _notesController.text.trim(),
          imageUrl: imageUrl,
          medicalDocuments: documents,
        );
        if (_pendingDocumentFiles.isNotEmpty) {
          final uploadedDocs = await _uploadPendingDocuments(
            repo: repo,
            userId: user.uid,
            animalId: created.id,
          );
          if (uploadedDocs.isNotEmpty) {
            await repo.updateAnimal(
              created.copyWith(
                medicalDocuments: [...documents, ...uploadedDocs],
              ),
            );
          }
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'animals_save_error'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'animals_edit'.tr() : 'animals_add'.tr(),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          FarmerHelperIconButton(guideSteps: _guideSteps),
        ],
      ),
      floatingActionButton: _isEditing && widget.animal != null
          ? FloatingActionButton.extended(
              onPressed: () => showVetFirstAidDialog(
                context: context,
                ref: ref,
                animal: widget.animal!,
              ),
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              icon: const Icon(Icons.medical_services_outlined),
              label: Text(farmerGuideTr(context, 'first_aid_button')),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            KeyedSubtree(
              key: _guidePhotoKey,
              child: GestureDetector(
                onTap: _showPhotoSourceSheet,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : _existingImageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                _existingImageUrl,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo,
                                    size: 48, color: Colors.green[700]),
                                const SizedBox(height: 8),
                                Text('animals_add_photo'.tr()),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: _guideIdentityKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'animals_name'.tr(),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.pets),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'animals_name_required'.tr()
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: AnimalRecord.speciesCodes.contains(_species)
                        ? _species
                        : AnimalRecord.normalizeSpecies(_species),
                    decoration: InputDecoration(
                      labelText: 'animals_species'.tr(),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                    items: AnimalRecord.speciesCodes
                        .map(
                          (code) => DropdownMenuItem(
                            value: code,
                            child: Text(AnimalRecord.speciesLabel(code)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _species = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _guideHealthKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _ageController,
                    decoration: InputDecoration(
                      labelText: 'animals_age'.tr(),
                      hintText: 'animals_age_hint'.tr(),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'animals_age_required'.tr()
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'animals_medical_notes'.tr(),
                      hintText: 'animals_notes_hint'.tr(),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 100),
                        child: Icon(Icons.medical_services_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _guideDocumentsKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showDocumentSourceSheet,
                    icon: const Icon(Icons.attach_file),
                    label: Text('animals_attach_document'.tr()),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                  Text(
                    'animals_attach_document_hint'.tr(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  _buildAttachedDocumentsPreview(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            KeyedSubtree(
              key: _guideSaveKey,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'profile_save'.tr(),
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
      ),
    );
  }
}

enum VeterinarianAnimalsTab { digitalIntake, fieldFindings }

/// Izbornik veterinara — digitalni prijem i terenski nalazi (bez kupčevog paketa 1,99 €).
class VeterinarianAnimalsHubScreen extends ConsumerStatefulWidget {
  const VeterinarianAnimalsHubScreen({
    super.key,
    this.initialTab = VeterinarianAnimalsTab.digitalIntake,
  });

  final VeterinarianAnimalsTab initialTab;

  @override
  ConsumerState<VeterinarianAnimalsHubScreen> createState() =>
      _VeterinarianAnimalsHubScreenState();
}

class _VeterinarianAnimalsHubScreenState
    extends ConsumerState<VeterinarianAnimalsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == VeterinarianAnimalsTab.fieldFindings
          ? 1
          : 0,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _canManageFieldReports() {
    return VeterinarFieldReportsTab.canManageReports(ref);
  }

  @override
  Widget build(BuildContext context) {
    final onFieldFindingsTab = _tabController.index == 1;
    final showFab = onFieldFindingsTab && _canManageFieldReports();

    return Scaffold(
      appBar: AppBar(
        title: Text(farmerGuideTr(context, 'vet_patient_records')),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
          tabs: [
            Tab(
              child: Text(
                farmerGuideTr(context, 'vet_tab_digital_intake'),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
            Tab(
              child: Text(
                farmerGuideTr(context, 'vet_animals_field_findings'),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: () =>
                  VeterinarFieldReportsTab.openAddForm(context, ref),
              backgroundColor: Colors.teal.shade800,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            _VetDigitalIntakePanel(),
            const VeterinarFieldReportsTab(),
          ],
        ),
      ),
    );
  }
}

class _VetDigitalIntakePanel extends ConsumerStatefulWidget {
  const _VetDigitalIntakePanel();

  @override
  ConsumerState<_VetDigitalIntakePanel> createState() =>
      _VetDigitalIntakePanelState();
}

enum _VetIntakeSort {
  newest,
  animalNameAz,
  clientNameAz,
  unreadFirst,
}

const _vetIntakePageSize = _animalsListPageSize;

class _VetDigitalIntakePanelState extends ConsumerState<_VetDigitalIntakePanel> {
  final _searchController = TextEditingController();
  final _listScrollController = ScrollController();
  _VetIntakeSort _sort = _VetIntakeSort.newest;
  int _currentPage = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _resetToFirstPage() => _currentPage = 0;

  void _goToPage(int page, int totalPages) {
    if (totalPages <= 0) return;
    setState(() => _currentPage = page.clamp(0, totalPages - 1));
    if (_listScrollController.hasClients) {
      _listScrollController.jumpTo(0);
    }
  }

  String _sortLabel(BuildContext context, _VetIntakeSort sort) {
    switch (sort) {
      case _VetIntakeSort.newest:
        return farmerGuideTr(
          context,
          'vet_intake_sort_newest',
          fallbacks: const {
            'hr': 'Najnovije',
            'de': 'Neueste',
            'en': 'Newest',
          },
        );
      case _VetIntakeSort.animalNameAz:
        return farmerGuideTr(
          context,
          'vet_intake_sort_animal_az',
          fallbacks: const {
            'hr': 'Životinja A–Z',
            'de': 'Tier A–Z',
            'en': 'Animal A–Z',
          },
        );
      case _VetIntakeSort.clientNameAz:
        return farmerGuideTr(
          context,
          'vet_intake_sort_client_az',
          fallbacks: const {
            'hr': 'Vlasnik A–Z',
            'de': 'Besitzer A–Z',
            'en': 'Owner A–Z',
          },
        );
      case _VetIntakeSort.unreadFirst:
        return farmerGuideTr(
          context,
          'vet_intake_sort_unread',
          fallbacks: const {
            'hr': 'Nepročitano',
            'de': 'Ungelesen',
            'en': 'Unread',
          },
        );
    }
  }

  int _requestTimestamp(VeterinaryRequest request) {
    final time = request.createdAt ?? request.updatedAt;
    return time?.millisecondsSinceEpoch ?? 0;
  }

  List<VeterinaryRequest> _filterAndSort(List<VeterinaryRequest> requests) {
    final query = _searchController.text.trim().toLowerCase();
    var filtered = requests.where((request) {
      if (query.isEmpty) return true;
      final haystack = [
        request.animalName,
        request.clientName,
        AnimalRecord.speciesLabel(request.animalSpecies),
        request.clientMemo,
        request.animalAge,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case _VetIntakeSort.animalNameAz:
          return a.animalName.toLowerCase().compareTo(b.animalName.toLowerCase());
        case _VetIntakeSort.clientNameAz:
          return a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
        case _VetIntakeSort.unreadFirst:
          final unreadDiff =
              b.unreadConversationCount.compareTo(a.unreadConversationCount);
          if (unreadDiff != 0) return unreadDiff;
          return _requestTimestamp(b).compareTo(_requestTimestamp(a));
        case _VetIntakeSort.newest:
          return _requestTimestamp(b).compareTo(_requestTimestamp(a));
      }
    });

    return filtered;
  }

  Widget _buildPaginationBar(
    BuildContext context, {
    required int currentPage,
    required int totalPages,
    required int rangeStart,
    required int rangeEnd,
    required int totalItems,
  }) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Material(
      elevation: 4,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: farmerGuideTr(
                  context,
                  'vet_intake_prev_page',
                  fallbacks: const {
                    'hr': 'Prethodna stranica',
                    'de': 'Vorherige Seite',
                    'en': 'Previous page',
                  },
                ),
                onPressed: currentPage > 0
                    ? () => _goToPage(currentPage - 1, totalPages)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      farmerGuideTr(
                        context,
                        'vet_intake_page',
                        fallbacks: const {
                          'hr': 'Stranica {current} od {total}',
                          'de': 'Seite {current} von {total}',
                          'en': 'Page {current} of {total}',
                        },
                      )
                          .replaceAll('{current}', '${currentPage + 1}')
                          .replaceAll('{total}', '$totalPages'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    Text(
                      farmerGuideTr(
                        context,
                        'vet_intake_page_range',
                        fallbacks: const {
                          'hr': '{from}–{to} od {total}',
                          'de': '{from}–{to} von {total}',
                          'en': '{from}–{to} of {total}',
                        },
                      )
                          .replaceAll('{from}', '$rangeStart')
                          .replaceAll('{to}', '$rangeEnd')
                          .replaceAll('{total}', '$totalItems'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: farmerGuideTr(
                  context,
                  'vet_intake_next_page',
                  fallbacks: const {
                    'hr': 'Sljedeća stranica',
                    'de': 'Nächste Seite',
                    'en': 'Next page',
                  },
                ),
                onPressed: currentPage < totalPages - 1
                    ? () => _goToPage(currentPage + 1, totalPages)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(vetIncomingRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('common_error'.tr(namedArgs: {'error': '$error'})),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 72, color: Colors.teal.shade300),
                  const SizedBox(height: 20),
                  Text(
                    farmerGuideTr(context, 'vet_animals_digital_intake'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    farmerGuideTr(context, 'vet_intake_empty'),
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

        final filtered = _filterAndSort(requests);
        final totalCount = requests.length;
        final visibleCount = filtered.length;
        final totalPages =
            visibleCount == 0 ? 0 : (visibleCount + _vetIntakePageSize - 1) ~/ _vetIntakePageSize;
        final currentPage = totalPages == 0
            ? 0
            : _currentPage.clamp(0, totalPages - 1);
        if (currentPage != _currentPage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentPage = currentPage);
          });
        }
        final pageStart = currentPage * _vetIntakePageSize;
        final pageEnd = (pageStart + _vetIntakePageSize).clamp(0, visibleCount);
        final pageItems = visibleCount == 0
            ? filtered
            : filtered.sublist(pageStart, pageEnd);
        final rangeStart = visibleCount == 0 ? 0 : pageStart + 1;
        final rangeEnd = visibleCount == 0 ? 0 : pageEnd;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.teal.shade50,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(_resetToFirstPage),
                      decoration: InputDecoration(
                        hintText: farmerGuideTr(
                          context,
                          'vet_intake_search_hint',
                          fallbacks: const {
                            'hr': 'Pretraži po životinji, vlasniku ili napomeni…',
                            'de':
                                'Suche nach Tier, Besitzer oder Hinweis…',
                            'en': 'Search by animal, owner, or note…',
                          },
                        ),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(_resetToFirstPage);
                                },
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.teal.shade100),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.teal.shade100),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.teal.shade400),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            visibleCount == totalCount
                                ? farmerGuideTr(
                                    context,
                                    'vet_intake_count_total',
                                    fallbacks: const {
                                      'hr': '{count} kartona',
                                      'de': '{count} Akten',
                                      'en': '{count} records',
                                    },
                                  ).replaceAll('{count}', '$totalCount')
                                : farmerGuideTr(
                                    context,
                                    'vet_intake_count_filtered',
                                    fallbacks: const {
                                      'hr': 'Prikazano {visible} od {total}',
                                      'de': '{visible} von {total} angezeigt',
                                      'en': 'Showing {visible} of {total}',
                                    },
                                  )
                                    .replaceAll('{visible}', '$visibleCount')
                                    .replaceAll('{total}', '$totalCount'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade900,
                            ),
                          ),
                        ),
                        PopupMenuButton<_VetIntakeSort>(
                          initialValue: _sort,
                          tooltip: farmerGuideTr(
                            context,
                            'vet_intake_sort_label',
                            fallbacks: const {
                              'hr': 'Sortiraj',
                              'de': 'Sortieren',
                              'en': 'Sort',
                            },
                          ),
                          onSelected: (value) => setState(() {
                            _sort = value;
                            _resetToFirstPage();
                          }),
                          itemBuilder: (context) => _VetIntakeSort.values
                              .map(
                                (option) => PopupMenuItem(
                                  value: option,
                                  child: Row(
                                    children: [
                                      if (_sort == option)
                                        Icon(
                                          Icons.check,
                                          size: 18,
                                          color: Colors.teal.shade700,
                                        )
                                      else
                                        const SizedBox(width: 18),
                                      const SizedBox(width: 8),
                                      Text(_sortLabel(context, option)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sort_rounded,
                                  size: 18,
                                  color: Colors.teal.shade800,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _sortLabel(context, _sort),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal.shade900,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.teal.shade800,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_outlined,
                              size: 64,
                              color: Colors.teal.shade200,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              farmerGuideTr(
                                context,
                                'vet_intake_no_results',
                                fallbacks: const {
                                  'hr':
                                      'Nema kartona za ovu pretragu. Pokušajte drugi pojam.',
                                  'de':
                                      'Keine Akten für diese Suche. Anderen Begriff versuchen.',
                                  'en':
                                      'No records match this search. Try another term.',
                                },
                              ),
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
                    )
                  : ListView.builder(
                      controller: _listScrollController,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: pageItems.length,
                      itemBuilder: (context, index) {
                        final request = pageItems[index];
                        final unread = request.unreadConversationCount;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: unread > 0
                                  ? Colors.teal.shade200
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade50,
                              child: request.animalImageUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        request.animalImageUrl,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.pets,
                                          color: Colors.teal.shade700,
                                        ),
                                      ),
                                    )
                                  : Icon(Icons.pets, color: Colors.teal.shade700),
                            ),
                            title: Text(
                              request.animalName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  '${request.clientName} · ${AnimalRecord.speciesLabel(request.animalSpecies)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (request.clientMemo.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    request.clientMemo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade900,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (unread > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade700,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.shade500,
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      VetPatientRequestDetailScreen(
                                    request: request,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            _buildPaginationBar(
              context,
              currentPage: currentPage,
              totalPages: totalPages,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              totalItems: visibleCount,
            ),
          ],
        );
      },
    );
  }
}

class VetPatientRequestDetailScreen extends ConsumerStatefulWidget {
  const VetPatientRequestDetailScreen({super.key, required this.request});

  final VeterinaryRequest request;

  @override
  ConsumerState<VetPatientRequestDetailScreen> createState() =>
      _VetPatientRequestDetailScreenState();
}

class _VetPatientRequestDetailScreenState
    extends ConsumerState<VetPatientRequestDetailScreen>
    with SingleTickerProviderStateMixin {
  final _responseController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  late TabController _detailTabController;

  @override
  void initState() {
    super.initState();
    _detailTabController = TabController(length: 2, vsync: this);
    _detailTabController.addListener(_handleDetailTabChange);
  }

  void _handleDetailTabChange() {
    if (_detailTabController.indexIsChanging) return;
    if (_detailTabController.index != 1) return;
    _markConversationRead();
  }

  Future<void> _markConversationRead() async {
    final request = ref.read(veterinaryRequestProvider(widget.request.id)).valueOrNull ??
        widget.request;
    final readCount = request.effectiveConversationMessages.length;
    if (readCount <= request.resolvedVetConversationReadCount) return;

    try {
      await ref.read(veterinaryRequestRepositoryProvider).markConversationAsRead(
            requestId: request.id,
            readCount: readCount,
          );
    } catch (_) {}
  }

  @override
  void dispose() {
    _detailTabController.removeListener(_handleDetailTabChange);
    _detailTabController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _submitResponse(VeterinaryRequest request) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await ref.read(veterinaryRequestRepositoryProvider).submitVetResponse(
            requestId: request.id,
            vetResponse: _responseController.text.trim(),
            vetName: user?.displayName,
          );
      if (!mounted) return;
      _responseController.clear();
      _formKey.currentState?.reset();
      await _markConversationRead();
      if (!mounted) return;
      _detailTabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            farmerGuideTr(
              context,
              'vet_response_sent',
              fallbacks: const {
                'hr': 'Nalaz je spremljen i poslan vlasniku.',
                'de': 'Befund wurde gespeichert und an den Besitzer gesendet.',
                'en': 'Report saved and sent to the owner.',
              },
            ),
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(veterinaryRequestProvider(widget.request.id));
    final request = requestAsync.valueOrNull ?? widget.request;
    final unreadCount = request.unreadConversationCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(request.animalName),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _detailTabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: farmerGuideTr(
                context,
                'vet_tab_patient_record',
                fallbacks: const {
                  'hr': 'Karton',
                  'de': 'Akte',
                  'en': 'Record',
                },
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    farmerGuideTr(
                      context,
                      'vet_tab_conversations',
                      fallbacks: const {
                        'hr': 'Razgovori',
                        'de': 'Unterhaltungen',
                        'en': 'Messages',
                      },
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _detailTabController,
          children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: _buildRecordTabContent(context, request),
            ),
          ),
          _VetConversationHistoryPanel(
            requestId: widget.request.id,
            request: request,
          ),
        ],
        ),
      ),
    );
  }

  List<Widget> _buildRecordTabContent(
    BuildContext context,
    VeterinaryRequest request,
  ) {
    return [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade300, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_alt_outlined,
                          color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text(
                        farmerGuideTr(
                          context,
                          'vet_client_memo_title',
                          fallbacks: const {
                            'hr': 'Napomena vlasnika',
                            'de': 'Hinweis des Besitzers',
                            'en': 'Owner note',
                          },
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    request.clientMemo.isNotEmpty
                        ? request.clientMemo
                        : farmerGuideTr(
                            context,
                            'vet_client_memo_empty',
                            fallbacks: const {
                              'hr': 'Vlasnik nije dodao napomenu.',
                              'de':
                                  'Der Besitzer hat keinen Hinweis hinzugefügt.',
                              'en': 'Owner did not add a note.',
                            },
                          ),
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (request.animalImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  request.animalImageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.pets, size: 64, color: Colors.teal.shade200),
              ),
            const SizedBox(height: 16),
            _vetDetailRow(
              farmerGuideTr(
                context,
                'vet_request_client',
                fallbacks: const {
                  'hr': 'Vlasnik',
                  'de': 'Besitzer',
                  'en': 'Owner',
                },
              ),
              request.clientName,
            ),
            _vetDetailRow('animals_species'.tr(),
                AnimalRecord.speciesLabel(request.animalSpecies)),
            _vetDetailRow('animals_age'.tr(), request.animalAge),
            const SizedBox(height: 16),
            if (request.medicalNotes.isNotEmpty) ...[
              Text(
                'animals_medical_notes'.tr(),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(request.medicalNotes),
              ),
              const SizedBox(height: 16),
            ],
            if (request.medicalHistory.isNotEmpty) ...[
              Text(
                'animals_medical_history'.tr(),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...request.medicalHistory.map(
                (entry) => _MedicalHistoryTile(entry: entry),
              ),
              const SizedBox(height: 16),
            ],
            if (request.medicalDocuments.isNotEmpty) ...[
              Text(
                'animals_attach_document'.tr(),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...request.medicalDocuments.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        doc.type == 'pdf'
                            ? Icons.picture_as_pdf
                            : Icons.image_outlined,
                        size: 18,
                        color: Colors.teal.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          doc.name.isEmpty ? doc.url : doc.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Divider(height: 32),
            Text(
              farmerGuideTr(
                context,
                'vet_response_form_title',
                fallbacks: const {
                  'hr': 'Stručni nalaz za vlasnika',
                  'de': 'Fachlicher Befund für den Besitzer',
                  'en': 'Professional report for owner',
                },
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              farmerGuideTr(
                context,
                'vet_response_field_label',
                fallbacks: const {
                  'hr':
                      'Upišite stručni savjet, uputu za liječenje ili nalaz za vlasnika.',
                  'de':
                      'Geben Sie den medizinischen Rat, die Behandlungsanweisung oder den Befund für den Besitzer ein.',
                  'en':
                      'Enter professional advice, treatment instructions, or findings for the owner.',
                },
              ),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _responseController,
              minLines: 5,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: farmerGuideTr(
                  context,
                  'vet_response_field_hint',
                  fallbacks: const {
                    'hr': 'Upišite nalaz ili uputu ovdje…',
                    'de': 'Befund oder Anweisung hier eingeben…',
                    'en': 'Enter your report or instructions here…',
                  },
                ),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.teal.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.teal.shade700, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.green.shade50,
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return farmerGuideTr(
                    context,
                    'vet_response_required',
                    fallbacks: const {
                      'hr': 'Molimo upišite nalaz ili uputu za vlasnika.',
                      'de': 'Bitte geben Sie einen Befund oder eine Anweisung ein.',
                      'en': 'Please enter a report or instructions for the owner.',
                    },
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : () => _submitResponse(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  farmerGuideTr(
                    context,
                    'vet_response_send',
                    fallbacks: const {
                      'hr': 'Spremi i pošalji nalaz',
                      'de': 'Befund speichern und senden',
                      'en': 'Save and send report',
                    },
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
    ];
  }

  Widget _vetDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _VetConversationHistoryPanel extends ConsumerStatefulWidget {
  const _VetConversationHistoryPanel({
    required this.requestId,
    required this.request,
  });

  final String requestId;
  final VeterinaryRequest request;

  @override
  ConsumerState<_VetConversationHistoryPanel> createState() =>
      _VetConversationHistoryPanelState();
}

class _VetConversationHistoryPanelState
    extends ConsumerState<_VetConversationHistoryPanel> {
  bool _showImportantOnly = false;

  String _formatSentAt(BuildContext context, DateTime? sentAt) {
    if (sentAt == null) return '';
    return DateFormat.yMMMd(context.locale.toString()).add_Hm().format(sentAt);
  }

  Future<void> _toggleImportant(
    VeterinaryRequest request,
    VetConversationMessage message,
  ) async {
    final isImportant = request.isMessageImportant(message);
    try {
      await ref
          .read(veterinaryRequestRepositoryProvider)
          .toggleMessageImportant(
            requestId: request.id,
            messageId: message.id,
            important: !isImportant,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common_error'.tr(namedArgs: {'error': '$error'}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final request =
        ref.watch(veterinaryRequestProvider(widget.requestId)).valueOrNull ??
            widget.request;
    final messages = _showImportantOnly
        ? request.importantConversationMessages
        : request.sortedConversationMessages;

    if (request.effectiveConversationMessages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 72, color: Colors.teal.shade300),
              const SizedBox(height: 20),
              Text(
                farmerGuideTr(
                  context,
                  'vet_tab_conversations',
                  fallbacks: const {
                    'hr': 'Razgovori',
                    'de': 'Unterhaltungen',
                    'en': 'Messages',
                  },
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                farmerGuideTr(
                  context,
                  'vet_conversations_empty',
                  fallbacks: const {
                    'hr':
                        'Još nema poslanih poruka. Napišite prvi nalaz na kartici Karton.',
                    'de':
                        'Noch keine Nachrichten gesendet. Schreiben Sie den ersten Befund unter Akte.',
                    'en':
                        'No messages sent yet. Write the first report on the Record tab.',
                  },
                ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(
                  farmerGuideTr(
                    context,
                    'vet_conversations_filter_all',
                    fallbacks: const {
                      'hr': 'Sve',
                      'de': 'Alle',
                      'en': 'All',
                    },
                  ),
                ),
                selected: !_showImportantOnly,
                onSelected: (_) => setState(() => _showImportantOnly = false),
                selectedColor: Colors.teal.shade100,
                checkmarkColor: Colors.teal.shade800,
              ),
              FilterChip(
                avatar: Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: _showImportantOnly
                      ? Colors.amber.shade800
                      : Colors.grey.shade600,
                ),
                label: Text(
                  farmerGuideTr(
                    context,
                    'vet_conversations_filter_important',
                    fallbacks: const {
                      'hr': 'Važno',
                      'de': 'Wichtig',
                      'en': 'Important',
                    },
                  ),
                ),
                selected: _showImportantOnly,
                onSelected: (_) => setState(() => _showImportantOnly = true),
                selectedColor: Colors.amber.shade100,
                checkmarkColor: Colors.amber.shade900,
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      farmerGuideTr(
                        context,
                        'vet_conversations_important_empty',
                        fallbacks: const {
                          'hr':
                              'Nema označenih važnih poruka. Dodirnite zvjezdicu uz poruku.',
                          'de':
                              'Keine wichtigen Nachrichten markiert. Tippen Sie auf den Stern.',
                          'en':
                              'No important messages marked. Tap the star on a message.',
                        },
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isImportant = request.isMessageImportant(message);
                    return Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
                          decoration: BoxDecoration(
                            color: isImportant
                                ? Colors.amber.shade50
                                : Colors.teal.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(4),
                            ),
                            border: Border.all(
                              color: isImportant
                                  ? Colors.amber.shade300
                                  : Colors.teal.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (message.vetName.isNotEmpty)
                                          Text(
                                            message.vetName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.teal.shade800,
                                            ),
                                          ),
                                        if (message.vetName.isNotEmpty)
                                          const SizedBox(height: 6),
                                        Text(
                                          message.text,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    tooltip: farmerGuideTr(
                                      context,
                                      isImportant
                                          ? 'vet_conversations_unmark_important'
                                          : 'vet_conversations_mark_important',
                                      fallbacks: isImportant
                                          ? const {
                                              'hr': 'Ukloni oznaku važno',
                                              'de': 'Markierung entfernen',
                                              'en': 'Remove important mark',
                                            }
                                          : const {
                                              'hr': 'Označi kao važno',
                                              'de': 'Als wichtig markieren',
                                              'en': 'Mark as important',
                                            },
                                    ),
                                    onPressed: () =>
                                        _toggleImportant(request, message),
                                    icon: Icon(
                                      isImportant
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: isImportant
                                          ? Colors.amber.shade800
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              if (_formatSentAt(context, message.sentAt)
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _formatSentAt(context, message.sentAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
