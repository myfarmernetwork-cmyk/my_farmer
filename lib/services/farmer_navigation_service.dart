import 'package:url_launcher/url_launcher.dart';

import '../features/community/utils/community_location_launcher.dart';

/// Opens Google Maps (or default maps app) with driving directions to a farmer/seller.
Future<bool> openFarmerDirections({
  required String name,
  String address = '',
  double? lat,
  double? lng,
}) async {
  final label = name.trim().isEmpty ? 'Farmer' : name.trim();
  final trimmedAddress = address.trim();

  if (lat != null && lng != null) {
    final encoded = Uri.encodeComponent(label);
    final uris = [
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
      ),
      Uri.parse('geo:$lat,$lng?q=$lat,$lng($encoded)'),
      Uri.parse('google.navigation:q=$lat,$lng'),
    ];

    for (final uri in uris) {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  if (trimmedAddress.isNotEmpty) {
    final destination = Uri.encodeComponent(trimmedAddress);
    final uris = [
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
      ),
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$destination',
      ),
    ];
    for (final uri in uris) {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  if (lat != null && lng != null) {
    return openCommunityLocationOnMap(
      locationLabel: label,
      lat: lat,
      lng: lng,
    );
  }

  return false;
}
