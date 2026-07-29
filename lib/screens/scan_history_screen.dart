import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scan_history_entry.dart';
import '../repositories/scan_history_repository.dart';
import '../widgets/translated_text.dart';

class ScanHistoryScreen extends ConsumerWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(userScanHistoryProvider);

    return Scaffold(
      key: ValueKey('scan_history_${context.locale}'),
      appBar: AppBar(
        title: Text('scan_history_title'.tr()),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('common_error'.tr(namedArgs: {'error': '$error'})),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'scan_history_empty'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              return _ScanHistoryCard(entry: entries[index]);
            },
          );
        },
      ),
    );
  }
}

class _ScanHistoryCard extends StatelessWidget {
  final ScanHistoryEntry entry;

  const _ScanHistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.createdAt?.toDate();
    final locale = context.locale.toString();
    final dateLabel = date != null
        ? DateFormat.yMMMd(locale).add_Hm().format(date)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  entry.imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 10),
            TranslatedText(
              entry.plantName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (entry.scientificName.isNotEmpty)
              Text(
                entry.scientificName,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            if (dateLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                dateLabel,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            if (entry.diagnosis.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'scan_history_diagnosis'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TranslatedText(entry.diagnosis),
            ],
            if (entry.recommendedTreatment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'scan_history_treatment'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green[800],
                ),
              ),
              TranslatedText(entry.recommendedTreatment),
            ],
          ],
        ),
      ),
    );
  }
}
