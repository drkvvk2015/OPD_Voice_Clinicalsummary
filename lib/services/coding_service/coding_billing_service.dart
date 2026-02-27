import '../../data/models/diagnosis_suggestion.dart';

class CodingBillingService {
  String buildSuggestion(List<DiagnosisSuggestion> diagnoses) {
    if (diagnoses.isEmpty) {
      return 'No diagnosis for coding; suggest manual coding.';
    }

    final top = diagnoses.first;
    final cpt = _suggestCpt(top.name);
    final codingConfidence = _confidenceBand(top.confidence);
    final denialRisk = _estimateDenialRisk(top);

    return 'Suggested primary ICD: ${top.icdCode} (${top.name}). '
        'CPT suggestion: $cpt (verify with payer policy). '
        'Coding confidence: $codingConfidence. Denial risk: $denialRisk.';
  }

  String _suggestCpt(String diagnosisName) {
    final lower = diagnosisName.toLowerCase();
    if (lower.contains('follow-up')) {
      return '99212';
    }
    if (lower.contains('acute') || lower.contains('infection')) {
      return '99213';
    }
    return '99214';
  }

  String _confidenceBand(double value) {
    if (value >= 0.85) return 'High';
    if (value >= 0.70) return 'Moderate';
    return 'Low';
  }

  String _estimateDenialRisk(DiagnosisSuggestion top) {
    if (top.icdCode == 'R69' || top.confidence < 0.70) {
      return 'Medium';
    }
    return 'Low';
  }
}
