import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/vet_navigation_service.dart';
import '../services/vet_proximity_radar_service.dart';
import '../widgets/vet_profile_sheet.dart';

/// Map of verified veterinarians with search and Google Maps navigation.
class VetFinderScreen extends ConsumerStatefulWidget {
  const VetFinderScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<VetFinderScreen> createState() => _VetFinderScreenState();
}

class _VetFinderScreenState extends ConsumerState<VetFinderScreen> {
  final _searchController = TextEditingController();
  GoogleMapController? _mapController;

  Position? _buyerPosition;
  List<VetProfile> _allVets = [];
  List<VetProfile> _visibleVets = [];
  bool _loading = true;
  String? _error;
  VetProfile? _selectedVet;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {}

      final radar = ref.read(vetProximityRadarServiceProvider);
      final vets = await radar.searchVetsByName(
        '',
        buyerPosition: position,
      );

      if (!mounted) return;

      setState(() {
        _buyerPosition = position;
        _allVets = vets;
        _loading = false;
      });
      _applySearch(_searchController.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _applySearch(String query) {
    final normalized = query.trim().toLowerCase();
    setState(() {
      if (normalized.length < 2) {
        _visibleVets = List<VetProfile>.from(_allVets);
      } else {
        _visibleVets = _allVets.where((v) {
          if (v.name.toLowerCase().contains(normalized)) return true;
          if (v.address.toLowerCase().contains(normalized)) return true;
          return false;
        }).toList();
      }
      if (_selectedVet != null &&
          !_visibleVets.any((v) => v.uid == _selectedVet!.uid)) {
        _selectedVet = null;
      }
    });
  }

  Set<Marker> _buildMarkers() {
    return _visibleVets.where((v) => v.hasLocation).map((vet) {
      final isSelected = _selectedVet?.uid == vet.uid;
      return Marker(
        markerId: MarkerId(vet.uid),
        position: LatLng(vet.lat!, vet.lng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          vet.isPremium
              ? BitmapDescriptor.hueGreen
              : isSelected
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueAzure,
        ),
        infoWindow: InfoWindow(
          title: vet.name,
          snippet: vet.isPremium ? 'Premium' : vet.address,
          onTap: () => _selectVet(vet),
        ),
        onTap: () => _selectVet(vet),
      );
    }).toSet();
  }

  void _selectVet(VetProfile vet) {
    setState(() => _selectedVet = vet);
    if (vet.hasLocation && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(vet.lat!, vet.lng!), 13),
      );
    }
  }

  LatLng _initialTarget() {
    if (_selectedVet?.hasLocation == true) {
      return LatLng(_selectedVet!.lat!, _selectedVet!.lng!);
    }
    if (_buyerPosition != null) {
      return LatLng(_buyerPosition!.latitude, _buyerPosition!.longitude);
    }
    final withLoc = _visibleVets.where((v) => v.hasLocation).toList();
    if (withLoc.isNotEmpty) {
      return LatLng(withLoc.first.lat!, withLoc.first.lng!);
    }
    return const LatLng(45.815, 15.9819);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('vet_finder_title'.tr()),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'vet_finder_search_hint'.tr(),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applySearch('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onChanged: _applySearch,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _initialTarget(),
                          zoom: 10,
                        ),
                        markers: _buildMarkers(),
                        myLocationEnabled: _buyerPosition != null,
                        myLocationButtonEnabled: _buyerPosition != null,
                        onMapCreated: (controller) => _mapController = controller,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: _visibleVets.isEmpty
                          ? Center(child: Text('vet_finder_empty'.tr()))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              itemCount: _visibleVets.length,
                              itemBuilder: (context, index) {
                                final vet = _visibleVets[index];
                                final selected = _selectedVet?.uid == vet.uid;
                                return Card(
                                  elevation: selected ? 3 : 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: selected
                                          ? Colors.green[600]!
                                          : Colors.grey[200]!,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    onTap: () => _selectVet(vet),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green[50],
                                      child: Icon(
                                        Icons.medical_services,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(vet.name)),
                                        if (vet.isPremium)
                                          Icon(
                                            Icons.verified,
                                            color: Colors.green[700],
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      [
                                        if (vet.address.isNotEmpty) vet.address,
                                        if (vet.distanceKm != null)
                                          '${vet.distanceKm!.toStringAsFixed(1)} km',
                                        if (!vet.hasLocation)
                                          'vet_map_no_location'.tr(),
                                      ].join(' · '),
                                    ),
                                    trailing: vet.hasLocation
                                        ? IconButton(
                                            tooltip: 'vet_navigate'.tr(),
                                            icon: Icon(
                                              Icons.directions,
                                              color: Colors.blue[700],
                                            ),
                                            onPressed: () =>
                                                openVetDirections(vet),
                                          )
                                        : null,
                                    onLongPress: () => showVetProfileSheet(
                                      context: context,
                                      ref: ref,
                                      vet: vet,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _selectedVet != null
          ? FloatingActionButton.extended(
              onPressed: () => showVetProfileSheet(
                context: context,
                ref: ref,
                vet: _selectedVet!,
              ),
              icon: const Icon(Icons.info_outline),
              label: Text('vet_details'.tr()),
            )
          : null,
    );
  }
}
