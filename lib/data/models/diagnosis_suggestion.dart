class DiagnosisSuggestion {
  const DiagnosisSuggestion({
    required this.name,
    required this.icdCode,
    required this.confidence,
    this.requiresConfirmation = false,
  });

  final String name;
  final String icdCode;
  final double confidence;
  final bool requiresConfirmation;

  Map<String, dynamic> toMap() => {
        'name': name,
        'icdCode': icdCode,
        'confidence': confidence,
        'requiresConfirmation': requiresConfirmation ? 1 : 0,
      };

  factory DiagnosisSuggestion.fromMap(Map<String, dynamic> map) {
    return DiagnosisSuggestion(
      name: map['name'] as String,
      icdCode: map['icdCode'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      requiresConfirmation: (map['requiresConfirmation'] as int? ?? 0) == 1,
    );
  }
}
