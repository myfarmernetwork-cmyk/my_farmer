class PlantDiseaseSuggestion {
  final String name;
  final double probability;
  final String? localName;
  final String? description;
  final String? treatment;

  const PlantDiseaseSuggestion({
    required this.name,
    required this.probability,
    this.localName,
    this.description,
    this.treatment,
  });

  factory PlantDiseaseSuggestion.fromMap(Map<String, dynamic> data) {
    final details = PlantScanResult._map(data['details']);
    final treatmentRaw = details['treatment'];

    String? treatmentText;
    if (treatmentRaw is Map) {
      final parts = <String>[];
      for (final entry in treatmentRaw.entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          parts.add('${entry.key}: ${entry.value}');
        }
      }
      treatmentText = parts.isEmpty ? null : parts.join('\n');
    } else if (treatmentRaw is String) {
      treatmentText = treatmentRaw;
    }

    return PlantDiseaseSuggestion(
      name: data['name'] as String? ?? '',
      probability: (data['probability'] as num?)?.toDouble() ?? 0,
      localName: details['local_name'] as String?,
      description: details['description'] as String?,
      treatment: treatmentText,
    );
  }
}

class PlantScanResult {
  final String? commonName;
  final String? scientificName;
  final double identificationConfidence;
  final bool isPlant;
  final bool? isHealthy;
  final double? healthProbability;
  final List<PlantDiseaseSuggestion> diseases;

  const PlantScanResult({
    this.commonName,
    this.scientificName,
    required this.identificationConfidence,
    required this.isPlant,
    this.isHealthy,
    this.healthProbability,
    this.diseases = const [],
  });

  bool get hasDiseaseSuggestions => diseases.isNotEmpty;

  factory PlantScanResult.fromJson(Map<String, dynamic> json) {
    final result = _map(json['result']);

    final isPlantData = _map(result['is_plant']);
    final isPlant = isPlantData['binary'] as bool? ?? true;

    final classification = _map(result['classification']);
    final suggestions = (classification['suggestions'] as List<dynamic>?) ?? [];

    String? commonName;
    String? scientificName;
    double confidence = 0;

    if (suggestions.isNotEmpty) {
      final top = _map(suggestions.first);
      scientificName = top['name'] as String?;
      confidence = (top['probability'] as num?)?.toDouble() ?? 0;

      final details = _map(top['details']);
      final commonNames = details['common_names'];
      if (commonNames is List && commonNames.isNotEmpty) {
        commonName = commonNames.first.toString();
      }
    }

    final diseaseBlock = _map(result['disease']);
    final isHealthyData = _optionalMap(diseaseBlock['is_healthy']);
    final diseaseSuggestions = (diseaseBlock['suggestions'] as List<dynamic>?)
            ?.map(
              (item) => PlantDiseaseSuggestion.fromMap(_map(item)),
            )
            .toList() ??
        [];

    return PlantScanResult(
      commonName: commonName,
      scientificName: scientificName,
      identificationConfidence: confidence,
      isPlant: isPlant,
      isHealthy: isHealthyData?['binary'] as bool?,
      healthProbability:
          (isHealthyData?['probability'] as num?)?.toDouble(),
      diseases: diseaseSuggestions,
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static Map<String, dynamic>? _optionalMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
