import 'package:flutter/foundation.dart';

import '../../ai/llama/llama_extractor.dart';
import '../../ai/whisper/whisper_cpp_adapter.dart';
import '../../ai/whisper/whisper_engine.dart';
import '../../data/db/local_database.dart';
import '../../data/models/diagnosis_suggestion.dart';
import '../../data/models/encounter.dart';
import '../../data/models/future/copilot_explainability.dart';
import '../../data/models/future/future_insights.dart';
import '../../data/models/patient.dart';
import '../../data/models/prescription_row.dart';
import '../../data/repositories/encounter_repository.dart';
import '../../services/audio_service/audio_service.dart';
import '../../services/coding_service/coding_billing_service.dart';
import '../../services/diagnosis_service/diagnosis_service.dart';
import '../../services/diagnosis_service/icd_mapper.dart';
import '../../services/digital_twin_service/digital_twin_service.dart';
import '../../services/extraction_service/clinical_extraction_service.dart';
import '../../services/extraction_service/structured_extraction_validator.dart';
import '../../services/export_service/opd_sheet_export_service.dart';
import '../../services/federated_service/federated_learning_service.dart';
import '../../services/longitudinal_service/longitudinal_service.dart';
import '../../services/multimodal_service/multimodal_ingestion_service.dart';
import '../../services/personalization_service/personalization_service.dart';
import '../../services/population_health_service/population_health_service.dart';
import '../../services/prescription_parser/prescription_parse_result.dart';
import '../../services/prescription_parser/prescription_parser_service.dart';
import '../../services/qa_service/documentation_qa_service.dart';
import '../../services/safety_service/clinical_safety_service.dart';
import '../../services/sync_service/sync_queue_service.dart';
import '../../services/voice_automation_service/voice_automation_service.dart';

class ConsultationController extends ChangeNotifier {
  ConsultationController({
    required AudioService audioService,
    required WhisperEngine whisperEngine,
    required ClinicalExtractionService extractionService,
    required DiagnosisService diagnosisService,
    required PrescriptionParserService prescriptionParserService,
    required EncounterRepository encounterRepository,
    required SyncQueueService syncQueueService,
    required PersonalizationService personalizationService,
    required LongitudinalService longitudinalService,
    required ClinicalSafetyService clinicalSafetyService,
    required DocumentationQaService documentationQaService,
    required FederatedLearningService federatedLearningService,
    required MultimodalIngestionService multimodalIngestionService,
    required CodingBillingService codingBillingService,
    required PopulationHealthService populationHealthService,
    required VoiceAutomationService voiceAutomationService,
    required DigitalTwinService digitalTwinService,
    required OpdSheetExportService opdSheetExportService,
  })  : _audioService = audioService,
        _whisperEngine = whisperEngine,
        _extractionService = extractionService,
        _diagnosisService = diagnosisService,
        _prescriptionParserService = prescriptionParserService,
        _encounterRepository = encounterRepository,
        _syncQueueService = syncQueueService,
        _personalizationService = personalizationService,
        _longitudinalService = longitudinalService,
        _clinicalSafetyService = clinicalSafetyService,
        _documentationQaService = documentationQaService,
        _federatedLearningService = federatedLearningService,
        _multimodalIngestionService = multimodalIngestionService,
        _codingBillingService = codingBillingService,
        _populationHealthService = populationHealthService,
        _voiceAutomationService = voiceAutomationService,
        _digitalTwinService = digitalTwinService,
        _opdSheetExportService = opdSheetExportService;

  factory ConsultationController.bootstrap() {
    final database = LocalDatabase();
    return ConsultationController(
      audioService: AudioService(),
      whisperEngine: WhisperEngine(WhisperCppAdapter()),
      extractionService: ClinicalExtractionService(
        LlamaExtractor(),
        StructuredExtractionValidator(),
      ),
      diagnosisService: DiagnosisService(),
      prescriptionParserService: PrescriptionParserService(),
      encounterRepository: EncounterRepository(database),
      syncQueueService: SyncQueueService(),
      personalizationService: PersonalizationService(),
      longitudinalService: LongitudinalService(),
      clinicalSafetyService: ClinicalSafetyService(),
      documentationQaService: DocumentationQaService(),
      federatedLearningService: FederatedLearningService(),
      multimodalIngestionService: MultimodalIngestionService(),
      codingBillingService: CodingBillingService(),
      populationHealthService: PopulationHealthService(),
      voiceAutomationService: VoiceAutomationService(),
      digitalTwinService: DigitalTwinService(),
      opdSheetExportService: const OpdSheetExportService(),
    );
  }

  final AudioService _audioService;
  final WhisperEngine _whisperEngine;
  final ClinicalExtractionService _extractionService;
  final DiagnosisService _diagnosisService;
  final PrescriptionParserService _prescriptionParserService;
  final EncounterRepository _encounterRepository;
  final SyncQueueService _syncQueueService;
  final PersonalizationService _personalizationService;
  final LongitudinalService _longitudinalService;
  final ClinicalSafetyService _clinicalSafetyService;
  final DocumentationQaService _documentationQaService;
  final FederatedLearningService _federatedLearningService;
  final MultimodalIngestionService _multimodalIngestionService;
  final CodingBillingService _codingBillingService;
  final PopulationHealthService _populationHealthService;
  final VoiceAutomationService _voiceAutomationService;
  final DigitalTwinService _digitalTwinService;
  final OpdSheetExportService _opdSheetExportService;
  final IcdMapper _icdMapper = IcdMapper();

  bool _isBusy = false;
  bool _isSyncing = false;
  bool _isExporting = false;
  String _transcript = '';
  String _patientName = 'Walk-in Patient';
  String _patientAgeInput = '36';
  String _patientGender = 'Unknown';
  String _allergiesInput = '';
  bool _isPregnant = false;
  bool _hasRenalRisk = false;
  bool _hasHepaticRisk = false;
  String? _errorMessage;
  String? _lastExportPath;
  Encounter? _latestEncounter;
  Encounter? _draftEncounter;
  String _draftTranscriptInput = '';
  String _draftComplaintsInput = '';
  String _draftHistoryInput = '';
  String _draftExaminationInput = '';
  String _draftInvestigationsInput = '';
  String _draftDiagnosisInput = '';
  String _draftMedicationInput = '';
  List<Encounter> _history = const [];
  List<String> _clinicalWarnings = const [];
  List<String> _interactionWarnings = const [];
  FutureInsights _futureInsights = FutureInsights.empty();
  CopilotExplainability _copilotExplainability = CopilotExplainability.empty();

  bool get isBusy => _isBusy;
  bool get isSyncing => _isSyncing;
  bool get isExporting => _isExporting;
  bool get isRecording => _audioService.isRecording;
  String get transcript => _transcript;
  String get patientName => _patientName;
  String get patientAgeInput => _patientAgeInput;
  String get patientGender => _patientGender;
  String get allergiesInput => _allergiesInput;
  bool get isPregnant => _isPregnant;
  bool get hasRenalRisk => _hasRenalRisk;
  bool get hasHepaticRisk => _hasHepaticRisk;
  String? get errorMessage => _errorMessage;
  String? get lastExportPath => _lastExportPath;
  Encounter? get latestEncounter => _latestEncounter;
  bool get hasDraft => _draftEncounter != null;
  String get draftTranscriptInput => _draftTranscriptInput;
  String get draftComplaintsInput => _draftComplaintsInput;
  String get draftHistoryInput => _draftHistoryInput;
  String get draftExaminationInput => _draftExaminationInput;
  String get draftInvestigationsInput => _draftInvestigationsInput;
  String get draftDiagnosisInput => _draftDiagnosisInput;
  String get draftMedicationInput => _draftMedicationInput;
  String get draftEncounterId => _draftEncounter?.id ?? '';
  Encounter? get reviewEncounter {
    if (_draftEncounter == null) {
      return _latestEncounter;
    }
    return _composeDraftData(strictValidation: false).encounter;
  }
  List<Encounter> get history => _history;
  List<String> get clinicalWarnings => _clinicalWarnings;
  List<String> get interactionWarnings => _interactionWarnings;
  int get pendingSyncCount => _syncQueueService.pending.length;
  FutureInsights get futureInsights => _futureInsights;
  CopilotExplainability get copilotExplainability => _copilotExplainability;

  void setPatientName(String value) {
    _patientName = value;
    notifyListeners();
  }

  void setPatientAgeInput(String value) {
    _patientAgeInput = value;
    notifyListeners();
  }

  void setPatientGender(String value) {
    _patientGender = _normalizeGender(value);
    notifyListeners();
  }

  void setAllergiesInput(String value) {
    _allergiesInput = value;
    notifyListeners();
  }

  void setPregnancyStatus(bool value) {
    _isPregnant = value;
    notifyListeners();
  }

  void setRenalRisk(bool value) {
    _hasRenalRisk = value;
    notifyListeners();
  }

  void setHepaticRisk(bool value) {
    _hasHepaticRisk = value;
    notifyListeners();
  }

  void setDraftTranscriptInput(String value) {
    _draftTranscriptInput = value;
  }

  void setDraftComplaintsInput(String value) {
    _draftComplaintsInput = value;
  }

  void setDraftHistoryInput(String value) {
    _draftHistoryInput = value;
  }

  void setDraftExaminationInput(String value) {
    _draftExaminationInput = value;
  }

  void setDraftInvestigationsInput(String value) {
    _draftInvestigationsInput = value;
  }

  void setDraftDiagnosisInput(String value) {
    _draftDiagnosisInput = value;
  }

  void setDraftMedicationInput(String value) {
    _draftMedicationInput = value;
  }

  Future<void> init() async {
    _history = await _encounterRepository.getAll();
    if (_history.isNotEmpty) {
      final patient = _history.first.patient;
      _patientName = patient.name;
      _patientAgeInput = patient.age.toString();
      _patientGender = _normalizeGender(patient.gender);
      _allergiesInput = patient.allergies.join(', ');
      _isPregnant = patient.isPregnant;
      _hasRenalRisk = patient.hasRenalRisk;
      _hasHepaticRisk = patient.hasHepaticRisk;
    }
    notifyListeners();
  }

  Future<void> toggleRecording() async {
    _errorMessage = null;
    if (_audioService.isRecording) {
      await _stopAndProcess();
      return;
    }

    await _audioService.startRecording();
    notifyListeners();
  }

  Future<void> _stopAndProcess() async {
    _isBusy = true;
    notifyListeners();

    try {
      final sessionId = await _audioService.stopRecording();
      if (sessionId == null) {
        throw StateError('No active recording session found.');
      }

      _transcript =
          await _whisperEngine.transcribe(sessionId, languageHint: 'en');
      await _generateEncounter(_transcript);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _generateEncounter(String transcript) async {
    final structured = await _extractionService.extract(transcript);
    final diagnoses = _diagnosisService.suggest(transcript);
    final PrescriptionParseResult parseResult =
        _prescriptionParserService.parse(transcript);

    final needsReview = diagnoses.any((d) => d.requiresConfirmation) ||
        structured.warnings.isNotEmpty;

    final encounter = Encounter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patient: _buildActivePatient(),
      createdAt: DateTime.now(),
      transcript: transcript,
      chiefComplaints: structured.chiefComplaints,
      history: structured.history,
      examination: structured.examination,
      diagnoses: diagnoses,
      investigations: structured.investigations,
      prescriptions: parseResult.rows,
      requiresClinicalReview: needsReview,
    );

    _draftEncounter = encounter;
    _initDraftEditor(encounter);
    _clinicalWarnings = structured.warnings;
    _interactionWarnings = parseResult.warnings;
    await _buildFutureInsights(
      encounter,
      historySnapshot: [encounter, ..._history],
    );
  }

  Future<void> _buildFutureInsights(
    Encounter encounter, {
    List<Encounter>? historySnapshot,
  }) async {
    final activeHistory = historySnapshot ?? _history;
    _copilotExplainability =
        _personalizationService.buildExplainability(activeHistory);
    final deviationAlerts =
        _longitudinalService.detectDeviationAlerts(activeHistory);
    final followUpPlan =
        _longitudinalService.buildFollowUpPlan(activeHistory);
    final safetyAlerts = <String>[
      ..._clinicalSafetyService.evaluate(encounter),
      ...deviationAlerts,
    ];
    final qaFindings = <String>[
      ..._documentationQaService.audit(encounter),
      if (deviationAlerts.isNotEmpty)
        'Longitudinal QA: ${deviationAlerts.length} deviation alert(s) require review.',
    ];
    final federatedStatus =
        await _federatedLearningService.createLocalUpdate(activeHistory);
    final personalizationMacros = _copilotExplainability.doctorMacros;
    final transcriptLower = encounter.transcript.toLowerCase();
    final imageCount =
        transcriptLower.contains('xray') || transcriptLower.contains('x-ray')
            ? 1
            : 0;
    final pdfCount = transcriptLower.contains('report') ? 1 : 0;
    final vitalsCount = transcriptLower.contains('blood pressure') ||
            transcriptLower.contains('temperature')
        ? 1
        : 0;

    _futureInsights = FutureInsights(
      personalizedTemplate:
          '${_copilotExplainability.templateSuggestion} Suggested follow-up: $followUpPlan',
      longitudinalSummary: _longitudinalService.summarize(activeHistory),
      safetyAlerts: safetyAlerts,
      qaFindings: qaFindings,
      federatedStatus: federatedStatus,
      multimodalSummary: _multimodalIngestionService.summarizeAssets(
        imageCount: imageCount,
        pdfCount: pdfCount,
        vitalsCount: vitalsCount,
      ),
      billingSummary:
          _codingBillingService.buildSuggestion(encounter.diagnoses),
      populationSignal: _populationHealthService.detectSignal(activeHistory),
      voiceActions: [
        ...personalizationMacros.map((m) => 'Macro: $m'),
        ..._voiceAutomationService.suggestActions(encounter.transcript),
      ],
      digitalTwinPlan: _digitalTwinService.simulatePlan(encounter),
    );
  }

  Patient _buildActivePatient() {
    final normalizedName =
        _patientName.trim().isEmpty ? 'Walk-in Patient' : _patientName.trim();
    final normalizedAge = int.tryParse(_patientAgeInput.trim());
    final age = normalizedAge != null && normalizedAge > 0 ? normalizedAge : 36;
    final normalizedAllergies = _allergiesInput
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final idSeed = normalizedName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final patientId = idSeed.isEmpty ? 'P001' : 'P_$idSeed';

    return Patient(
      id: patientId,
      name: normalizedName,
      age: age,
      gender: _normalizeGender(_patientGender),
      allergies: normalizedAllergies,
      isPregnant: _isPregnant,
      hasRenalRisk: _hasRenalRisk,
      hasHepaticRisk: _hasHepaticRisk,
    );
  }

  String _normalizeGender(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'm' || normalized == 'male') {
      return 'Male';
    }
    if (normalized == 'f' || normalized == 'female') {
      return 'Female';
    }
    if (normalized == 'other') {
      return 'Other';
    }
    return 'Unknown';
  }

  Future<void> flushSyncQueue() async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _syncQueueService.flush();
    } catch (error) {
      _errorMessage = 'Sync failed: $error';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> exportLatestEncounter() async {
    if (_latestEncounter == null) {
      _errorMessage = 'No encounter available for export.';
      notifyListeners();
      return;
    }

    _isExporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _lastExportPath =
          await _opdSheetExportService.exportEncounterPdf(_latestEncounter!);
    } catch (error) {
      _errorMessage = 'Export failed: $error';
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}
