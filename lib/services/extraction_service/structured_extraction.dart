class StructuredExtraction {
  const StructuredExtraction({
    required this.chiefComplaints,
    required this.history,
    required this.examination,
    required this.investigations,
    required this.warnings,
  });

  final List<String> chiefComplaints;
  final String history;
  final String examination;
  final List<String> investigations;
  final List<String> warnings;
}
