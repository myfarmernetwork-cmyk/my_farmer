import 'package:url_launcher/url_launcher.dart';

import 'vet_proximity_radar_service.dart';

/// Opens Google Maps (or default maps app) with driving directions to a vet.
Future<bool> openVetDirections(VetProfile vet) async {
  if (!vet.hasLocation) return false;

  final lat = vet.lat!;
  final lng = vet.lng!;
  final label = vet.name.trim().isEmpty ? 'Veterinarian' : vet.name.trim();
  final encoded = Uri.encodeComponent(label);

  final uris = [
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=&travelmode=driving',
    ),
    Uri.parse('geo:$lat,$lng?q=$lat,$lng($encoded)'),
    Uri.parse('google.navigation:q=$lat,$lng'),
  ];

  for (final uri in uris) {
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  return false;
}

Future<bool> openVetOnMap(VetProfile vet) async {
  if (!vet.hasLocation) return false;

  final lat = vet.lat!;
  final lng = vet.lng!;
  final label = vet.name.trim().isEmpty ? 'Veterinarian' : vet.name.trim();
  final encoded = Uri.encodeComponent(label);

  final uris = [
    Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=',
    ),
    Uri.parse('geo:$lat,$lng?q=$lat,$lng($encoded)'),
  ];

  for (final uri in uris) {
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  return false;
}
