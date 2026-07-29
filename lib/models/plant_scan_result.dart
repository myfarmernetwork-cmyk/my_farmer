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
    final details = data['details'] as Map<String, dynamic>? ?? {};
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
    final result = json['result'] as Map<String, dynamic>? ?? {};

    final isPlantData = result['is_plant'] as Map<String, dynamic>? ?? {};
    final isPlant = isPlantData['binary'] as bool? ?? true;

    final classification =
        result['classification'] as Map<String, dynamic>? ?? {};
    final suggestions =
        (classification['suggestions'] as List<dynamic>?) ?? [];

    String? commonName;
    String? scientificName;
    double confidence = 0;

    if (suggestions.isNotEmpty) {
      final top = suggestions.first as Map<String, dynamic>;
      scientificName = top['name'] as String?;
      confidence = (top['probability'] as num?)?.toDouble() ?? 0;

      final details = top['details'] as Map<String, dynamic>? ?? {};
      final commonNames = details['common_names'];
      if (commonNames is List && commonNames.isNotEmpty) {
        commonName = commonNames.first.toString();
      }
    }

    final diseaseBlock = result['disease'] as Map<String, dynamic>? ?? {};
    final isHealthyData = diseaseBlock['is_healthy'] as Map<String, dynamic>?;
    final diseaseSuggestions = (diseaseBlock['suggestions'] as List<dynamic>?)
            ?.map(
              (item) => PlantDiseaseSuggestion.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
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
}
