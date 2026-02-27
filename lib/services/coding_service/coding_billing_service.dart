import '../../data/models/diagnosis_suggestion.dart';

class CodingBillingService {
  String buildSuggestion(List<DiagnosisSuggestion> diagnoses) {
    if (diagnoses.isEmpty) {
      return 'No diagnosis for coding; suggest manual coding.';
    }
    final top = diagnoses.first;
    return 'Suggested primary ICD: ${top.icdCode} (${top.name}). CPT suggestion: 99213 (verify with payer policy).';
  }
}
