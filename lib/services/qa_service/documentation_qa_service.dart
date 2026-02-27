import '../../data/models/encounter.dart';

class DocumentationQaService {
  List<String> audit(Encounter encounter) {
    final findings = <String>[];

    if (encounter.history.trim().isEmpty) {
      findings.add('History section is empty.');
    }
    if (encounter.examination.trim().isEmpty) {
      findings.add('Examination section is empty.');
    }
    if (encounter.diagnoses.isEmpty) {
      findings.add('No diagnosis suggestions documented.');
    }
    if (encounter.requiresClinicalReview) {
      findings.add('Encounter marked for clinician review before finalization.');
    }

    return findings;
  }
}
