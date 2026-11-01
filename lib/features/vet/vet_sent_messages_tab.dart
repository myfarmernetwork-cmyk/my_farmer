import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vet_conversation_message.dart';
import '../../models/veterinary_request.dart';
import '../../repositories/veterinary_request_repository.dart';
import '../../utils/scroll_bottom_padding.dart';
import '../../widgets/farmer_help_widgets.dart';

typedef VetOpenPatientMessagesCallback = void Function(
  VeterinaryRequest request,
);

class _VetSentMessageItem {
  const _VetSentMessageItem({
    required this.request,
    required this.message,
  });

  final VeterinaryRequest request;
  final VetConversationMessage message;

  bool isImportant() => request.isMessageImportant(message);
}

/// Tab s poslanim porukama klijentima (sve + označene zvjezdicom).
class VetSentMessagesTab extends ConsumerStatefulWidget {
  const VetSentMessagesTab({
    super.key,
    required this.onOpenPatientMessages,
  });

  final VetOpenPatientMessagesCallback onOpenPatientMessages;

  @override
  ConsumerState<VetSentMessagesTab> createState() => _VetSentMessagesTabState();
}

class _VetSentMessagesTabState extends ConsumerState<VetSentMessagesTab> {
  final _searchController = TextEditingController();
  bool _showImportantOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_VetSentMessageItem> _buildItems(List<VeterinaryRequest> requests) {
    final items = <_VetSentMessageItem>[];
    for (final request in requests) {
      for (final message in request.effectiveConversationMessages) {
        items.add(_VetSentMessageItem(request: request, message: message));
      }
    }
    items.sort((a, b) {
      final aImportant = a.isImportant();
      final bImportant = b.isImportant();
      if (aImportant != bImportant) {
        return aImportant ? -1 : 1;
      }
      final aTime = a.message.sentAt;
      final bTime = b.message.sentAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return items;
  }

  List<_VetSentMessageItem> _filterItems(List<_VetSentMessageItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      if (_showImportantOnly && !item.isImportant()) return false;
      if (query.isEmpty) return true;
      final haystack = [
        item.message.text,
        item.request.clientName,
        item.request.animalName,
        item.request.animalSpecies,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  String _formatSentAt(BuildContext context, DateTime? sentAt) {
    if (sentAt == null) return '';
    return DateFormat.yMMMd(context.locale.toString()).add_Hm().format(sentAt);
  }

  Future<void> _toggleImportant(_VetSentMessageItem item) async {
    final isImportant = item.isImportant();
    try {
      await ref.read(veterinaryRequestRepositoryProvider).toggleMessageImportant(
            requestId: item.request.id,
            messageId: item.message.id,
            important: !isImportant,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common_error'.tr(namedArgs: {'error': '$error'}))),
      );
    }
  }

  void _openPatientMessages(_VetSentMessageItem item) {
    widget.onOpenPatientMessages(item.request);
  }

  void _showMessageActions(_VetSentMessageItem item) {
    final isImportant = item.isImportant();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.request.animalName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.request.clientName} · ${item.request.animalSpecies}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isImportant ? Colors.amber.shade50 : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isImportant
                        ? Colors.amber.shade300
                        : Colors.teal.shade200,
                  ),
                ),
                child: Text(
                  item.message.text,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                ),
              ),
              if (_formatSentAt(context, item.message.sentAt).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _formatSentAt(context, item.message.sentAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openPatientMessages(item);
                },
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(
                  farmerGuideTr(
                    context,
                    'vet_sent_messages_open_patient',
                    fallbacks: const {
                      'hr': 'Otvori karton pacijenta',
                      'de': 'Patientenakte öffnen',
                      'en': 'Open patient record',
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: item.message.text),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        farmerGuideTr(
                          context,
                          'vet_sent_messages_copied',
                          fallbacks: const {
                            'hr': 'Poruka kopirana.',
                            'de': 'Nachricht kopiert.',
                            'en': 'Message copied.',
                          },
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                label: Text(
                  farmerGuideTr(
                    context,
                    'vet_sent_messages_copy',
                    fallbacks: const {
                      'hr': 'Kopiraj tekst',
                      'de': 'Text kopieren',
                      'en': 'Copy text',
                    },
                  ),
                ),
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
        final allItems = _buildItems(requests);
        final visibleItems = _filterItems(allItems);

        if (allItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.outbox_outlined, size: 72, color: Colors.teal.shade300),
                  const SizedBox(height: 20),
                  Text(
                    farmerGuideTr(
                      context,
                      'vet_sent_messages_title',
                      fallbacks: const {
                        'hr': 'Poslane poruke',
                        'de': 'Gesendete Nachrichten',
                        'en': 'Sent messages',
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
                      'vet_sent_messages_empty',
                      fallbacks: const {
                        'hr':
                            'Još nema poslanih poruka klijentima. Pošaljite prvi nalaz iz digitalnog kartona.',
                        'de':
                            'Noch keine Nachrichten an Kunden gesendet. Senden Sie den ersten Befund über die digitale Akte.',
                        'en':
                            'No messages sent to clients yet. Send the first report from a digital intake record.',
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
            Material(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: farmerGuideTr(
                          context,
                          'vet_sent_messages_search_hint',
                          fallbacks: const {
                            'hr': 'Pretraži poruke, klijente, životinje…',
                            'de': 'Nachrichten, Kunden, Tiere suchen…',
                            'en': 'Search messages, clients, animals…',
                          },
                        ),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
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
                    Wrap(
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
                          onSelected: (_) =>
                              setState(() => _showImportantOnly = false),
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
                          onSelected: (_) =>
                              setState(() => _showImportantOnly = true),
                          selectedColor: Colors.amber.shade100,
                          checkmarkColor: Colors.amber.shade900,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      farmerGuideTr(
                        context,
                        'vet_sent_messages_count',
                        fallbacks: const {
                          'hr': '{count} poruka',
                          'de': '{count} Nachrichten',
                          'en': '{count} messages',
                        },
                      ).replaceAll('{count}', '${visibleItems.length}'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: visibleItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _showImportantOnly
                              ? farmerGuideTr(
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
                                )
                              : farmerGuideTr(
                                  context,
                                  'vet_sent_messages_no_results',
                                  fallbacks: const {
                                    'hr': 'Nema poruka za ovu pretragu.',
                                    'de': 'Keine Nachrichten für diese Suche.',
                                    'en': 'No messages match this search.',
                                  },
                                ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: ScrollBottomPadding.list(context),
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        final isImportant = item.isImportant();
                        final preview = item.message.text.trim();
                        final shortPreview = preview.length > 140
                            ? '${preview.substring(0, 140)}…'
                            : preview;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: isImportant ? Colors.amber.shade50 : null,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showMessageActions(item),
                            onLongPress: () => _openPatientMessages(item),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.request.animalName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            if (isImportant)
                                              Icon(
                                                Icons.star_rounded,
                                                size: 18,
                                                color: Colors.amber.shade800,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.request.clientName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          shortPreview,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                        if (_formatSentAt(
                                          context,
                                          item.message.sentAt,
                                        ).isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            _formatSentAt(
                                              context,
                                              item.message.sentAt,
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
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
                                    onPressed: () => _toggleImportant(item),
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
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
