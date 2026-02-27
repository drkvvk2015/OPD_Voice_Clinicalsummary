import 'package:rxnova_clinical_ai/ai/llama/llama_extractor.dart';
import 'package:rxnova_clinical_ai/data/evaluation/evaluation_metrics.dart';
import 'package:rxnova_clinical_ai/services/diagnosis_service/diagnosis_service.dart';
import 'package:rxnova_clinical_ai/services/extraction_service/clinical_extraction_service.dart';
import 'package:rxnova_clinical_ai/services/extraction_service/structured_extraction_validator.dart';
import 'package:rxnova_clinical_ai/services/prescription_parser/prescription_parser_service.dart';

Future<void> main() async {
  final extractionService = ClinicalExtractionService(LlamaExtractor(), StructuredExtractionValidator());
  final diagnosisService = DiagnosisService();
  final prescriptionService = PrescriptionParserService();

  const dataset = <EvaluationSample>[
    EvaluationSample(
      transcript: 'Fever with cough for two days. Advise CBC. Start paracetamol 650 mg thrice daily for 5 days.',
      expectedComplaints: ['Fever', 'Cough'],
      expectedDiagnoses: ['Upper respiratory tract infection'],
      expectedDrugCount: 1,
    ),
    EvaluationSample(
      transcript: 'Severe throat pain with fever. Prescribe cetirizine 10 mg once daily for 3 days.',
      expectedComplaints: ['Fever', 'Sore throat'],
      expectedDiagnoses: ['Acute pharyngitis'],
      expectedDrugCount: 1,
    ),
  ];

  var complaintTruePositive = 0;
  var complaintPredicted = 0;
  var diagnosisTruePositive = 0;
  var diagnosisExpected = 0;
  var prescriptionCorrect = 0;

  for (final sample in dataset) {
    final extraction = await extractionService.extract(sample.transcript);
    final diagnoses = diagnosisService.suggest(sample.transcript);
    final prescriptions = prescriptionService.parse(sample.transcript);

    complaintPredicted += extraction.chiefComplaints.length;
    for (final complaint in extraction.chiefComplaints) {
      if (sample.expectedComplaints.contains(complaint)) {
        complaintTruePositive += 1;
      }
    }

    diagnosisExpected += sample.expectedDiagnoses.length;
    for (final diagnosis in diagnoses) {
      if (sample.expectedDiagnoses.contains(diagnosis.name)) {
        diagnosisTruePositive += 1;
      }
    }

    if (prescriptions.rows.length == sample.expectedDrugCount) {
      prescriptionCorrect += 1;
    }
  }

  final report = EvaluationReport(
    complaintPrecision: complaintPredicted == 0 ? 0 : complaintTruePositive / complaintPredicted,
    diagnosisRecall: diagnosisExpected == 0 ? 0 : diagnosisTruePositive / diagnosisExpected,
    prescriptionAccuracy: prescriptionCorrect / dataset.length,
  );

  print('Complaint precision: ${(report.complaintPrecision * 100).toStringAsFixed(1)}%');
  print('Diagnosis recall: ${(report.diagnosisRecall * 100).toStringAsFixed(1)}%');
  print('Prescription accuracy: ${(report.prescriptionAccuracy * 100).toStringAsFixed(1)}%');
}
