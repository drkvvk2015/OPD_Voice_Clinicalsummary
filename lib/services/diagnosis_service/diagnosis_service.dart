import '../../data/models/diagnosis_suggestion.dart';
import 'icd_mapper.dart';

class DiagnosisService {
  DiagnosisService({IcdMapper? icdMapper, this.confirmationThreshold = 0.7}) : _icdMapper = icdMapper ?? IcdMapper();

  final IcdMapper _icdMapper;
  final double confirmationThreshold;

  List<DiagnosisSuggestion> suggest(String transcript) {
    final lower = transcript.toLowerCase();
    final labels = <({String name, double confidence})>[];

    if (lower.contains('fever') && lower.contains('cough')) {
      labels.add((name: 'Upper respiratory tract infection', confidence: 0.86));
    }
    if (lower.contains('throat')) {
      labels.add((name: 'Acute pharyngitis', confidence: 0.73));
    }
    if (lower.contains('fever') && !lower.contains('cough')) {
      labels.add((name: 'Viral fever', confidence: 0.66));
    }

    if (labels.isEmpty) {
      labels.add((name: 'General OPD follow-up', confidence: 0.40));
    }

    return labels
        .map(
          (item) => DiagnosisSuggestion(
            name: item.name,
            icdCode: _icdMapper.resolveCode(item.name),
            confidence: item.confidence,
            requiresConfirmation: item.confidence < confirmationThreshold,
          ),
        )
        .toList(growable: false);
  }
}
