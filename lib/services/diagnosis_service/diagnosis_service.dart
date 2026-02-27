import '../../data/models/diagnosis_suggestion.dart';

class DiagnosisService {
  List<DiagnosisSuggestion> suggest(String transcript) {
    final lower = transcript.toLowerCase();
    final result = <DiagnosisSuggestion>[];

    if (lower.contains('fever') && lower.contains('cough')) {
      result.add(const DiagnosisSuggestion(name: 'Upper respiratory tract infection', icdCode: 'J06.9', confidence: 0.86));
    }
    if (lower.contains('throat')) {
      result.add(const DiagnosisSuggestion(name: 'Acute pharyngitis', icdCode: 'J02.9', confidence: 0.73));
    }
    if (result.isEmpty) {
      result.add(const DiagnosisSuggestion(name: 'General OPD follow-up', icdCode: 'Z09', confidence: 0.40));
    }
    return result;
  }
}
