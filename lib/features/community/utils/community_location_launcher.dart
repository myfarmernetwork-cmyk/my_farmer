import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps for a community author location (coordinates or place name).
Future<bool> openCommunityLocationOnMap({
  required String locationLabel,
  double? lat,
  double? lng,
}) async {
  final label = locationLabel.trim();
  if (label.isEmpty && (lat == null || lng == null)) return false;

  final uris = <Uri>[];
  if (lat != null && lng != null) {
    final encoded = Uri.encodeComponent(
      label.isEmpty ? 'Location' : label,
    );
    uris.addAll([
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      ),
      Uri.parse('geo:$lat,$lng?q=$lat,$lng($encoded)'),
    ]);
  }
  if (label.isNotEmpty) {
    uris.add(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(label)}',
      ),
    );
  }

  for (final uri in uris) {
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  return false;
}
