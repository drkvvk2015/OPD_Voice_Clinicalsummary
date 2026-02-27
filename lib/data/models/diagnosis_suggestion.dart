class DiagnosisSuggestion {
  const DiagnosisSuggestion({
    required this.name,
    required this.icdCode,
    required this.confidence,
  });

  final String name;
  final String icdCode;
  final double confidence;
}
