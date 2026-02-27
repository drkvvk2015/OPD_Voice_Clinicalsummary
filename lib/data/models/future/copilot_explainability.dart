class CopilotExplainability {
  const CopilotExplainability({
    required this.templateSuggestion,
    required this.rationale,
    required this.evidenceSignals,
    required this.doctorMacros,
  });

  final String templateSuggestion;
  final String rationale;
  final List<String> evidenceSignals;
  final List<String> doctorMacros;

  factory CopilotExplainability.empty() {
    return const CopilotExplainability(
      templateSuggestion: 'No personalized template yet.',
      rationale: 'Insufficient encounter history for explainability.',
      evidenceSignals: <String>[],
      doctorMacros: <String>[],
    );
  }
}
