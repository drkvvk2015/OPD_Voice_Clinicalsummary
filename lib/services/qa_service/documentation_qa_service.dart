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
      findings
          .add('Encounter marked for clinician review before finalization.');
    }

    final diagnosisText =
        encounter.diagnoses.map((d) => d.name.toLowerCase()).join(' ');
    final investigationsText = encounter.investigations.join(' ').toLowerCase();
    final medicationText =
        encounter.prescriptions.map((p) => p.drug.toLowerCase()).join(' ');

    if (diagnosisText.contains('viral') &&
        (medicationText.contains('azithromycin') ||
            medicationText.contains('amoxicillin'))) {
      findings.add(
        'Consistency check: viral diagnosis with antibiotic therapy detected; '
        'document clear clinical justification.',
      );
    }

    if (encounter.chiefComplaints.any((c) => c.toLowerCase() == 'fever') &&
        !investigationsText.contains('cbc') &&
        !investigationsText.contains('crp')) {
      findings.add(
          'Protocol check: fever complaint without baseline CBC/CRP documentation.');
    }

    if (encounter.chiefComplaints
            .any((c) => c.toLowerCase().contains('cough')) &&
        encounter.examination.toLowerCase().contains('general physical')) {
      findings.add(
          'Documentation quality: cough present but focused respiratory exam details are sparse.');
    }

    return findings;
  }
}
