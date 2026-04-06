class PetProfile {
  final String id;
  final String ownerId;
  final String name;
  final String breed;
  final int ageMonths;
  final double baselineWeight;

  PetProfile({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.breed,
    required this.ageMonths,
    required this.baselineWeight,
  });

  factory PetProfile.fromJson(Map<String, dynamic> json) {
    return PetProfile(
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      name: json['name'] ?? '',
      breed: json['breed'] ?? '',
      ageMonths: json['age_months'] ?? 0,
      baselineWeight: (json['baseline_weight'] ?? 0.0).toDouble(),
    );
  }
}

class PetScanResult {
  final String id;
  final String petId;
  final double bodyConditionScore;
  final double coatHealthScore;
  final double eyeClarityScore;
  final double dentalPlaqueScore;
  final String? rawDetections;
  final String imageUrl;
  final String timestamp;

  PetScanResult({
    required this.id,
    required this.petId,
    required this.bodyConditionScore,
    required this.coatHealthScore,
    required this.eyeClarityScore,
    required this.dentalPlaqueScore,
    this.rawDetections,
    required this.imageUrl,
    required this.timestamp,
  });

  factory PetScanResult.fromJson(Map<String, dynamic> json) {
    return PetScanResult(
      id: json['id'] ?? '',
      petId: json['pet_id'] ?? '',
      bodyConditionScore: (json['body_condition_score'] ?? 0.0).toDouble(),
      coatHealthScore: (json['coat_health_score'] ?? 0.0).toDouble(),
      eyeClarityScore: (json['eye_clarity_score'] ?? 0.0).toDouble(),
      dentalPlaqueScore: (json['dental_plaque_score'] ?? 0.0).toDouble(),
      rawDetections: json['raw_detections'],
      imageUrl: json['image_url'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class BackendStatusMessage {
  final String status;
  final String message;

  BackendStatusMessage({required this.status, required this.message});

  factory BackendStatusMessage.fromJson(Map<String, dynamic> json) {
    return BackendStatusMessage(
      status: json['status'] ?? 'unknown',
      message: json['details']?['message'] ?? '',
    );
  }
}
