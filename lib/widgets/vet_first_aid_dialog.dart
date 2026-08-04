import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/chat/chat_screen.dart';
import '../models/animal_record.dart';
import '../providers/subscription_provider.dart';
import '../repositories/veterinary_request_repository.dart';
import '../services/vet_navigation_service.dart';
import '../services/vet_proximity_radar_service.dart';
import 'farmer_help_widgets.dart';

Future<void> showVetFirstAidDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AnimalRecord animal,
}) async {
  final user = ref.read(userDocProvider).valueOrNull;
  final favoriteVetId = user?.favoriteVetId;
  final radar = ref.read(vetProximityRadarServiceProvider);

  Position? position;
  try {
    position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 8),
    );
  } catch (_) {}

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (ctx) => _VetReferralSheet(
      animal: animal,
      favoriteVetId: favoriteVetId,
      buyerPosition: position,
      radar: radar,
      clientName: user?.name,
    ),
  );
}

class _VetReferralSheet extends ConsumerStatefulWidget {
  const _VetReferralSheet({
    required this.animal,
    required this.favoriteVetId,
    required this.buyerPosition,
    required this.radar,
    this.clientName,
  });

  final AnimalRecord animal;
  final String? favoriteVetId;
  final Position? buyerPosition;
  final VetProximityRadarService radar;
  final String? clientName;

  @override
  ConsumerState<_VetReferralSheet> createState() => _VetReferralSheetState();
}

class _VetReferralSheetState extends ConsumerState<_VetReferralSheet> {
  final _memoController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<VetProfile> _vets = [];
  List<VetProfile> _filteredVets = [];
  bool _loading = true;
  bool _searching = false;
  bool _sending = false;
  String? _error;
  VetProfile? _selectedVet;

  @override
  void initState() {
    super.initState();
    _loadVets();
  }

  @override
  void dispose() {
    _memoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyLocalFilter(String query) {
    final normalized = query.trim().toLowerCase();
    setState(() {
      if (normalized.length < 2) {
        _filteredVets = List<VetProfile>.from(_vets);
      } else {
        _filteredVets = _vets
            .where((v) => v.name.toLowerCase().contains(normalized))
            .toList();
      }
      if (_selectedVet != null &&
          !_filteredVets.any((v) => v.uid == _selectedVet!.uid)) {
        _selectedVet = null;
      }
    });
  }

  Future<void> _searchVetsByName(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) {
      _applyLocalFilter(query);
      return;
    }

    setState(() => _searching = true);
    try {
      final vets = await widget.radar.searchVetsByName(
        normalized,
        buyerPosition: widget.buyerPosition,
      );
      if (!mounted) return;
      setState(() {
        _vets = vets;
        _filteredVets = vets;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _loadVets() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final vets = await widget.radar.resolveFirstAidVets(
        buyerPosition: widget.buyerPosition,
        favoriteVetId: widget.favoriteVetId,
      );
      if (mounted) {
        setState(() {
          _vets = vets;
          _filteredVets = vets;
          _loading = false;
          if (vets.length == 1) {
            _selectedVet = vets.first;
          } else if (widget.favoriteVetId != null) {
            for (final vet in vets) {
              if (vet.uid == widget.favoriteVetId) {
                _selectedVet = vet;
                break;
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(VetProfile vet) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isFavorite = widget.favoriteVetId == vet.uid;
    await widget.radar.setFavoriteVet(
      userId: currentUser.uid,
      vetId: isFavorite ? null : vet.uid,
    );
    if (!mounted) return;
    await _loadVets();
  }

  Future<void> _callVet(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalized.isEmpty) return;
    final uri = Uri.parse('tel:$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openChat(VetProfile vet) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: vet.uid,
          receiverName: vet.name,
        ),
      ),
    );
  }

  Future<void> _submitReferral() async {
    if (!_formKey.currentState!.validate() || _selectedVet == null) return;

    setState(() => _sending = true);

    try {
      await ref.read(veterinaryRequestRepositoryProvider).submitReferral(
            animal: widget.animal,
            vetId: _selectedVet!.uid,
            vetName: _selectedVet!.name,
            clientMemo: _memoController.text.trim(),
            clientName: widget.clientName,
          );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            farmerGuideTr(
              context,
              'vet_referral_sent',
              fallbacks: const {
                'hr': 'Karton je uspješno poslan veterinaru.',
                'de': 'Die Akte wurde erfolgreich an den Tierarzt gesendet.',
                'en': 'Medical record sent to the veterinarian.',
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
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.medical_services,
                        color: Colors.red[700],
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farmerGuideTr(
                              context,
                              'vet_referral_title',
                              fallbacks: const {
                                'hr': 'Slanje kartona veterinaru',
                                'de': 'Akte an Tierarzt senden',
                                'en': 'Send record to veterinarian',
                              },
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.animal.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      )
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!),
                          )
                        : _vets.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  farmerGuideTr(context, 'first_aid_no_vets'),
                                ),
                              )
                            : _filteredVets.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text('vet_finder_empty'.tr()),
                                  )
                                : Form(
                                    key: _formKey,
                                    child: ListView(
                                      padding: EdgeInsets.fromLTRB(
                                        20,
                                        12,
                                        20,
                                        _selectedVet != null ? 12 : 24 + bottomSafe,
                                      ),
                                      shrinkWrap: true,
                                      children: [
                                        TextField(
                                          controller: _searchController,
                                          decoration: InputDecoration(
                                            hintText:
                                                'vet_search_by_name_hint'.tr(),
                                            prefixIcon:
                                                const Icon(Icons.search),
                                            suffixIcon: _searchController
                                                    .text.isNotEmpty
                                                ? IconButton(
                                                    icon:
                                                        const Icon(Icons.clear),
                                                    onPressed: () {
                                                      _searchController.clear();
                                                      _applyLocalFilter('');
                                                    },
                                                  )
                                                : _searching
                                                    ? const Padding(
                                                        padding:
                                                            EdgeInsets.all(12),
                                                        child: SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        ),
                                                      )
                                                    : null,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey[50],
                                          ),
                                          onChanged: (value) {
                                            _applyLocalFilter(value);
                                            _searchVetsByName(value);
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          farmerGuideTr(
                                            context,
                                            'vet_referral_select_vet',
                                            fallbacks: const {
                                              'hr':
                                                  'Odaberite veterinara (omiljeni ili iz radara blizine):',
                                              'de':
                                                  'Wählen Sie einen Tierarzt (Favorit oder aus der Nähe):',
                                              'en':
                                                  'Select a veterinarian (favorite or nearby radar):',
                                            },
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ..._filteredVets.map(
                                          (vet) => _VetSelectionTile(
                                            vet: vet,
                                            isSelected:
                                                _selectedVet?.uid == vet.uid,
                                            isFavorite:
                                                widget.favoriteVetId == vet.uid,
                                            onSelect: () => setState(
                                                () => _selectedVet = vet),
                                            onFavorite: () =>
                                                _toggleFavorite(vet),
                                            onCall: vet.phone.isNotEmpty
                                                ? () => _callVet(vet.phone)
                                                : null,
                                            onChat: () => _openChat(vet),
                                            onNavigate: vet.hasLocation
                                                ? () => openVetDirections(vet)
                                                : null,
                                          ),
                                        ),
                                        if (_selectedVet != null) ...[
                                          const SizedBox(height: 20),
                                          TextFormField(
                                            controller: _memoController,
                                            maxLines: 3,
                                            decoration: InputDecoration(
                                              labelText: farmerGuideTr(
                                                context,
                                                'vet_referral_memo_label',
                                                fallbacks: const {
                                                  'hr':
                                                      'Opišite kratko simptome ili razlog slanja bolesne životinje (npr. povišena temperatura, odbija hranu...)',
                                                  'de':
                                                      'Beschreiben Sie kurz die Symptome oder den Grund für die Übersendung des kranken Tieres (z. B. erhöhte Temperatur, frisst nicht...)',
                                                  'en':
                                                      'Briefly describe symptoms or reason for sending the sick animal (e.g. fever, refusing food...)',
                                                },
                                              ),
                                              alignLabelWithHint: true,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              filled: true,
                                              fillColor: Colors.orange[50],
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return farmerGuideTr(
                                                  context,
                                                  'vet_referral_memo_required',
                                                  fallbacks: const {
                                                    'hr':
                                                        'Molimo opišite simptome ili razlog slanja.',
                                                    'de':
                                                        'Bitte beschreiben Sie die Symptome oder den Grund.',
                                                    'en':
                                                        'Please describe symptoms or reason for sending.',
                                                  },
                                                );
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
              ),
              if (_selectedVet != null && !_loading && _error == null)
                Material(
                  elevation: 8,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _submitReferral,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _sending
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
                            'vet_referral_send',
                            fallbacks: const {
                              'hr': 'Pošalji karton veterinaru',
                              'de': 'Akte an Tierarzt senden',
                              'en': 'Send record to vet',
                            },
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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

class _VetSelectionTile extends StatelessWidget {
  const _VetSelectionTile({
    required this.vet,
    required this.isSelected,
    required this.isFavorite,
    required this.onSelect,
    required this.onFavorite,
    this.onCall,
    required this.onChat,
    this.onNavigate,
  });

  final VetProfile vet;
  final bool isSelected;
  final bool isFavorite;
  final VoidCallback onSelect;
  final VoidCallback onFavorite;
  final VoidCallback? onCall;
  final VoidCallback onChat;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final distanceLabel = vet.distanceKm != null
        ? '${vet.distanceKm!.toStringAsFixed(1)} km'
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? Colors.red[400]! : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected ? Colors.red[700] : Colors.grey[500],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vet.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (vet.isFavorite)
                    Icon(Icons.star, color: Colors.amber[700], size: 20),
                  if (vet.isPremium)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Text(
                        farmerGuideTr(context, 'vet_verified_badge'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: Colors.amber[700],
                    ),
                    onPressed: onFavorite,
                    tooltip: farmerGuideTr(context, 'first_aid_favorite'),
                  ),
                ],
              ),
              if (vet.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Text(
                    vet.address,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
              if (distanceLabel != null)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 2),
                  child: Text(
                    distanceLabel,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Row(
                  children: [
                    if (onCall != null)
                      TextButton.icon(
                        onPressed: onCall,
                        icon: const Icon(Icons.phone_outlined, size: 18),
                        label: Text(farmerGuideTr(context, 'first_aid_call')),
                      ),
                    if (onNavigate != null)
                      TextButton.icon(
                        onPressed: onNavigate,
                        icon: const Icon(Icons.directions, size: 18),
                        label: Text('vet_navigate'.tr()),
                      ),
                    TextButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text(farmerGuideTr(context, 'first_aid_chat')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
