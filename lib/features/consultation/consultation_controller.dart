import 'dart:async';

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
import '../../data/repositories/encounter_repository.dart';
import '../../services/audio_service/audio_service.dart';
import '../../services/coding_service/coding_billing_service.dart';
import '../../services/diagnosis_service/diagnosis_service.dart';
import '../../services/diagnosis_service/icd_mapper.dart';
import '../../services/digital_twin_service/digital_twin_service.dart';
import '../../services/extraction_service/clinical_extraction_service.dart';
import '../../services/extraction_service/structured_extraction.dart';
import '../../services/extraction_service/structured_extraction_validator.dart';
import '../../services/ehr_service/ehr_integration_service.dart';
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
    required EhrIntegrationService ehrIntegrationService,
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
        _opdSheetExportService = opdSheetExportService,
        _ehrIntegrationService = ehrIntegrationService;

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
      ehrIntegrationService: const EhrIntegrationService(),
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
  final EhrIntegrationService _ehrIntegrationService;
  final IcdMapper _icdMapper = IcdMapper();

  bool _isBusy = false;
  bool _isSyncing = false;
  bool _isExporting = false;
  String _transcript = '';
  String _patientName = '';
  String _patientAgeInput = '';
  String _patientGender = 'Unknown';
  String _allergiesInput = '';
  bool _isPregnant = false;
  bool _hasRenalRisk = false;
  bool _hasHepaticRisk = false;
  bool _patientNameTouched = false;
  bool _patientAgeTouched = false;
  bool _patientGenderTouched = false;
  bool _isMicChecking = false;
  double _voiceLevel = 0;
  String _liveTranscript = '';
  List<String> _liveComplaints = const [];
  List<String> _liveVitals = const [];
  List<String> _liveLabReports = const [];
  List<String> _liveInvestigations = const [];
  List<String> _liveReferrals = const [];
  List<String> _liveMedicalPlan = const [];
  List<String> _liveSurgicalPlan = const [];
  List<String> _liveAdvice = const [];
  List<String> _liveDiagnoses = const [];
  String _liveMedicationPreview = '';
  String _liveDetectedLanguage = 'Unknown';
  String _liveAiReport = 'Waiting for live voice input...';
  bool _liveAnalysisBusy = false;
  String _lastAnalyzedLiveTranscript = '';
  String _liveCorrectionInput = '';
  bool _liveCorrectionDirty = false;
  static const int _minimumCompletenessScore = 85;
  Timer? _micUiTimer;
  String? _errorMessage;
  String? _lastExportPath;
  bool _isEhrSyncing = false;
  String _ehrEndpoint = '';
  String _ehrApiToken = '';
  EhrSystemType _ehrSystemType = EhrSystemType.fhirR4;
  bool _ehrIncludeTranscript = true;
  bool _ehrIncludePdfLink = true;
  bool _ehrAutoSyncOnSave = false;
  String? _ehrStatusMessage;
  String? _lastEhrPayloadPath;
  Encounter? _latestEncounter;
  Encounter? _draftEncounter;
  String _draftTranscriptInput = '';
  String _draftComplaintsInput = '';
  String _draftHistoryInput = '';
  String _draftExaminationInput = '';
  String _draftClinicalFindingsInput = '';
  String _draftVitalsInput = '';
  String _draftLabReportsInput = '';
  String _draftInvestigationsInput = '';
  String _draftReferralsInput = '';
  String _draftMedicalPlanInput = '';
  String _draftSurgicalPlanInput = '';
  String _draftAdviceInput = '';
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
  bool get isMicChecking => _isMicChecking;
  double get voiceLevel => _voiceLevel;
  String get liveTranscript => _liveTranscript;
  List<String> get liveComplaints => _liveComplaints;
  List<String> get liveVitals => _liveVitals;
  List<String> get liveLabReports => _liveLabReports;
  List<String> get liveInvestigations => _liveInvestigations;
  List<String> get liveReferrals => _liveReferrals;
  List<String> get liveMedicalPlan => _liveMedicalPlan;
  List<String> get liveSurgicalPlan => _liveSurgicalPlan;
  List<String> get liveAdvice => _liveAdvice;
  List<String> get liveDiagnoses => _liveDiagnoses;
  String get liveMedicationPreview => _liveMedicationPreview;
  String get liveDetectedLanguage => _liveDetectedLanguage;
  String get liveAiReport => _liveAiReport;
  String get liveCorrectionInput => _liveCorrectionInput;
  bool get isEhrSyncing => _isEhrSyncing;
  String get ehrEndpoint => _ehrEndpoint;
  String get ehrApiToken => _ehrApiToken;
  EhrSystemType get ehrSystemType => _ehrSystemType;
  bool get ehrIncludeTranscript => _ehrIncludeTranscript;
  bool get ehrIncludePdfLink => _ehrIncludePdfLink;
  bool get ehrAutoSyncOnSave => _ehrAutoSyncOnSave;
  String? get ehrStatusMessage => _ehrStatusMessage;
  String? get lastEhrPayloadPath => _lastEhrPayloadPath;
  int get minimumCompletenessScore => _minimumCompletenessScore;
  String? get errorMessage => _errorMessage;
  String? get lastExportPath => _lastExportPath;
  Encounter? get latestEncounter => _latestEncounter;
  bool get hasDraft => _draftEncounter != null;
  String get draftTranscriptInput => _draftTranscriptInput;
  String get draftComplaintsInput => _draftComplaintsInput;
  String get draftHistoryInput => _draftHistoryInput;
  String get draftExaminationInput => _draftExaminationInput;
  String get draftClinicalFindingsInput => _draftClinicalFindingsInput;
  String get draftVitalsInput => _draftVitalsInput;
  String get draftLabReportsInput => _draftLabReportsInput;
  String get draftInvestigationsInput => _draftInvestigationsInput;
  String get draftReferralsInput => _draftReferralsInput;
  String get draftMedicalPlanInput => _draftMedicalPlanInput;
  String get draftSurgicalPlanInput => _draftSurgicalPlanInput;
  String get draftAdviceInput => _draftAdviceInput;
  String get draftDiagnosisInput => _draftDiagnosisInput;
  String get draftMedicationInput => _draftMedicationInput;
  String get draftEncounterId => _draftEncounter?.id ?? '';
  int get completenessScore {
    final encounter = reviewEncounter;
    if (encounter == null) {
      return 0;
    }
    return _calculateCompleteness(encounter).score;
  }

  List<String> get missingMandatorySections {
    final encounter = reviewEncounter;
    if (encounter == null) {
      return const ['No encounter available'];
    }
    return _calculateCompleteness(encounter).missingSections;
  }

  bool get isCompletenessPassed =>
      completenessScore >= _minimumCompletenessScore;
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
    _patientNameTouched = true;
  }

  void setPatientAgeInput(String value) {
    _patientAgeInput = value;
    _patientAgeTouched = true;
  }

  void setPatientGender(String value) {
    _patientGender = _normalizeGender(value);
    _patientGenderTouched = true;
  }

  void setAllergiesInput(String value) {
    _allergiesInput = value;
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

  void setLiveCorrectionInput(String value) {
    _liveCorrectionInput = value;
    _liveCorrectionDirty = true;
  }

  Future<void> applyLiveCorrection() async {
    final corrected = _liveCorrectionInput.trim();
    if (corrected.isEmpty) {
      return;
    }
    _liveTranscript = corrected;
    _transcript = corrected;
    _lastAnalyzedLiveTranscript = '';
    _autoPopulatePatientFromVoice(corrected, notify: false);
    await _runLiveAnalysis(corrected);
    notifyListeners();
  }

  void resetLiveCorrection() {
    _liveCorrectionDirty = false;
    _liveCorrectionInput = _liveTranscript;
    notifyListeners();
  }

  void setEhrEndpoint(String value) {
    _ehrEndpoint = value;
  }

  void setEhrApiToken(String value) {
    _ehrApiToken = value;
  }

  void setEhrSystemType(EhrSystemType value) {
    _ehrSystemType = value;
    notifyListeners();
  }

  void setEhrIncludeTranscript(bool value) {
    _ehrIncludeTranscript = value;
    notifyListeners();
  }

  void setEhrIncludePdfLink(bool value) {
    _ehrIncludePdfLink = value;
    notifyListeners();
  }

  void setEhrAutoSyncOnSave(bool value) {
    _ehrAutoSyncOnSave = value;
    notifyListeners();
  }

  void setDraftTranscriptInput(String value) {
    _draftTranscriptInput = value;
    notifyListeners();
  }

  void setDraftComplaintsInput(String value) {
    _draftComplaintsInput = value;
    notifyListeners();
  }

  void setDraftHistoryInput(String value) {
    _draftHistoryInput = value;
    notifyListeners();
  }

  void setDraftExaminationInput(String value) {
    _draftExaminationInput = value;
    notifyListeners();
  }

  void setDraftClinicalFindingsInput(String value) {
    _draftClinicalFindingsInput = value;
    notifyListeners();
  }

  void setDraftVitalsInput(String value) {
    _draftVitalsInput = value;
    notifyListeners();
  }

  void setDraftLabReportsInput(String value) {
    _draftLabReportsInput = value;
    notifyListeners();
  }

  void setDraftInvestigationsInput(String value) {
    _draftInvestigationsInput = value;
    notifyListeners();
  }

  void setDraftReferralsInput(String value) {
    _draftReferralsInput = value;
    notifyListeners();
  }

  void setDraftMedicalPlanInput(String value) {
    _draftMedicalPlanInput = value;
    notifyListeners();
  }

  void setDraftSurgicalPlanInput(String value) {
    _draftSurgicalPlanInput = value;
    notifyListeners();
  }

  void setDraftAdviceInput(String value) {
    _draftAdviceInput = value;
    notifyListeners();
  }

  void setDraftDiagnosisInput(String value) {
    _draftDiagnosisInput = value;
    notifyListeners();
  }

  void setDraftMedicationInput(String value) {
    _draftMedicationInput = value;
    notifyListeners();
  }

  Future<void> init() async {
    _history = await _encounterRepository.getAll();
    _latestEncounter = _history.isEmpty ? null : _history.first;
    notifyListeners();
  }

  Future<void> toggleRecording() async {
    _errorMessage = null;
    if (_audioService.isRecording) {
      await _stopAndProcess();
      return;
    }

    if (_draftEncounter != null) {
      _errorMessage =
          'Please confirm/save or export the current draft before starting a new consultation.';
      notifyListeners();
      return;
    }

    _liveTranscript = '';
    _liveComplaints = const [];
    _liveVitals = const [];
    _liveLabReports = const [];
    _liveInvestigations = const [];
    _liveReferrals = const [];
    _liveMedicalPlan = const [];
    _liveSurgicalPlan = const [];
    _liveAdvice = const [];
    _liveDiagnoses = const [];
    _liveMedicationPreview = '';
    _liveDetectedLanguage = 'Unknown';
    _liveAiReport = 'Listening...';
    _lastAnalyzedLiveTranscript = '';
    _liveCorrectionInput = '';
    _liveCorrectionDirty = false;

    await _audioService.startRecording();
    if (!_audioService.isSpeechAvailable &&
        _audioService.lastSpeechError != null) {
      _errorMessage =
          'Live speech recognition is unavailable: ${_audioService.lastSpeechError}. '
          'Please allow microphone permission and use a supported target.';
    }
    _startMicUiUpdates();
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

      final spokenTranscript = _audioService.finalTranscript.trim();
      if (spokenTranscript.isNotEmpty) {
        _transcript = spokenTranscript;
      } else {
        _transcript =
            await _whisperEngine.transcribe(sessionId, languageHint: 'en');
      }
      _liveCorrectionInput = _transcript;
      _liveCorrectionDirty = false;
      _autoPopulatePatientFromVoice(_transcript);
      await _generateEncounter(_transcript);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _stopMicUiUpdates();
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _generateEncounter(String transcript) async {
    final structured = await _extractionService.extract(transcript);
    final diagnoses = _diagnosisService.suggest(transcript);
    final PrescriptionParseResult parseResult =
        _prescriptionParserService.parse(transcript);

    _applyStructuredPatientDetails(structured);

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
      clinicalFindings: structured.clinicalFindings,
      vitals: structured.vitals,
      labReports: structured.labReports,
      diagnoses: diagnoses,
      investigations: structured.investigations,
      referralConsultations: structured.referralConsultations,
      medicalPlan: structured.medicalPlan,
      surgicalPlan: structured.surgicalPlan,
      advice: structured.advice,
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
    final followUpPlan = _longitudinalService.buildFollowUpPlan(activeHistory);
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

  void _initDraftEditor(Encounter encounter) {
    _draftTranscriptInput = encounter.transcript;
    _draftComplaintsInput = encounter.chiefComplaints.join(', ');
    _draftHistoryInput = encounter.history;
    _draftExaminationInput = encounter.examination;
    _draftClinicalFindingsInput = encounter.clinicalFindings;
    _draftVitalsInput = encounter.vitals.join(', ');
    _draftLabReportsInput = encounter.labReports.join(', ');
    _draftInvestigationsInput = encounter.investigations.join(', ');
    _draftReferralsInput = encounter.referralConsultations.join(', ');
    _draftMedicalPlanInput = encounter.medicalPlan.join(', ');
    _draftSurgicalPlanInput = encounter.surgicalPlan.join(', ');
    _draftAdviceInput = encounter.advice.join(', ');
    _draftDiagnosisInput = encounter.diagnoses.map((d) => d.name).join(', ');
    _draftMedicationInput = encounter.prescriptions.isEmpty
        ? ''
        : encounter.prescriptions
            .map((p) =>
                '${p.drug} ${p.dose} ${p.frequency} for ${p.duration} ${p.route}')
            .join('. ');
  }

  ({
    Encounter encounter,
    List<String> clinicalWarnings,
    List<String> interactionWarnings,
  }) _composeDraftData({
    required bool strictValidation,
  }) {
    final seed = _draftEncounter;
    if (seed == null) {
      throw StateError('No draft encounter is available.');
    }

    final transcript = _draftTranscriptInput.trim().isEmpty
        ? seed.transcript
        : _draftTranscriptInput.trim();
    final complaints = _parseListInput(_draftComplaintsInput);
    final history = _draftHistoryInput.trim().isEmpty
        ? seed.history
        : _draftHistoryInput.trim();
    final examination = _draftExaminationInput.trim().isEmpty
        ? seed.examination
        : _draftExaminationInput.trim();
    final clinicalFindings = _draftClinicalFindingsInput.trim().isEmpty
        ? seed.clinicalFindings
        : _draftClinicalFindingsInput.trim();
    final vitals = _parseListInput(_draftVitalsInput);
    final labReports = _parseListInput(_draftLabReportsInput);
    final investigations = _parseListInput(_draftInvestigationsInput);
    final referrals = _parseListInput(_draftReferralsInput);
    final medicalPlan = _parseListInput(_draftMedicalPlanInput);
    final surgicalPlan = _parseListInput(_draftSurgicalPlanInput);
    final advice = _parseListInput(_draftAdviceInput);
    final diagnoses = _buildDiagnosesFromInput(_draftDiagnosisInput,
        fallback: seed.diagnoses);

    final medicationText = _draftMedicationInput.trim();
    final parseResult = medicationText.isEmpty
        ? const PrescriptionParseResult(rows: [], warnings: [])
        : _prescriptionParserService.parse(medicationText);

    final clinicalWarnings = <String>[
      if (complaints.isEmpty)
        'No chief complaint provided in edited draft; review required.',
      if (history.trim().isEmpty)
        'History is empty in edited draft; review required.',
      if (examination.trim().isEmpty)
        'Examination is empty in edited draft; review required.',
      if (investigations.isEmpty)
        'No investigations listed in edited draft; verify intent.',
      if (vitals.isEmpty) 'No vitals captured in edited draft; verify values.',
      if (medicalPlan.isEmpty && surgicalPlan.isEmpty)
        'No treatment plan captured in edited draft; verify management plan.',
    ];

    if (strictValidation) {
      if (complaints.isEmpty) {
        throw const FormatException(
          'Please add at least one chief complaint before confirming save/export.',
        );
      }
      if (history.trim().isEmpty) {
        throw const FormatException(
          'Please add history details before confirming.',
        );
      }
      if (examination.trim().isEmpty) {
        throw const FormatException(
            'Please add examination details before confirming.');
      }
    }

    final requiresClinicalReview =
        diagnoses.any((d) => d.requiresConfirmation) ||
            clinicalWarnings.isNotEmpty;

    final composedEncounter = Encounter(
      id: seed.id,
      patient: _buildActivePatient(),
      createdAt: seed.createdAt,
      transcript: transcript,
      chiefComplaints: complaints,
      history: history,
      examination: examination,
      clinicalFindings: clinicalFindings,
      vitals: vitals,
      labReports: labReports,
      diagnoses: diagnoses,
      investigations: investigations,
      referralConsultations: referrals,
      medicalPlan: medicalPlan,
      surgicalPlan: surgicalPlan,
      advice: advice,
      prescriptions: parseResult.rows,
      requiresClinicalReview: requiresClinicalReview,
    );

    if (strictValidation) {
      final completeness = _calculateCompleteness(composedEncounter);
      if (completeness.score < _minimumCompletenessScore) {
        throw FormatException(
          'Completeness score is ${completeness.score}% (minimum $_minimumCompletenessScore%). '
          'Missing: ${completeness.missingSections.join(', ')}.',
        );
      }
    }

    return (
      encounter: composedEncounter,
      clinicalWarnings: clinicalWarnings,
      interactionWarnings: parseResult.warnings,
    );
  }

  List<DiagnosisSuggestion> _buildDiagnosesFromInput(
    String raw, {
    required List<DiagnosisSuggestion> fallback,
  }) {
    final entries = _parseListInput(raw);
    if (entries.isEmpty) {
      return fallback;
    }

    return entries
        .map((entry) {
          final match = RegExp(r'^(.*?)(?:\s*\(([^)]+)\))?$').firstMatch(entry);
          final name = (match?.group(1) ?? entry).trim();
          final explicitCode = (match?.group(2) ?? '').trim();
          const confidence = 0.80;
          return DiagnosisSuggestion(
            name: name,
            icdCode: explicitCode.isEmpty
                ? _icdMapper.resolveCode(name)
                : explicitCode,
            confidence: confidence,
            requiresConfirmation:
                confidence < _diagnosisService.confirmationThreshold,
          );
        })
        .where((d) => d.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<String> _parseListInput(String raw) {
    return raw
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  ({int score, List<String> missingSections}) _calculateCompleteness(
    Encounter encounter,
  ) {
    final checks = <({String section, bool complete})>[
      (
        section: 'Patient name',
        complete: encounter.patient.name.trim().isNotEmpty &&
            encounter.patient.name.trim().toLowerCase() != 'walk-in patient',
      ),
      (
        section: 'Patient age',
        complete: encounter.patient.age > 0 && encounter.patient.age < 130,
      ),
      (
        section: 'Patient gender',
        complete: encounter.patient.gender.trim().toLowerCase() != 'unknown',
      ),
      (
        section: 'Chief complaints',
        complete: encounter.chiefComplaints.isNotEmpty,
      ),
      (section: 'History', complete: encounter.history.trim().isNotEmpty),
      (
        section: 'Examination',
        complete: encounter.examination.trim().isNotEmpty
      ),
      (
        section: 'Clinical findings',
        complete: encounter.clinicalFindings.trim().isNotEmpty,
      ),
      (section: 'Vitals', complete: encounter.vitals.isNotEmpty),
      (section: 'Lab reports', complete: encounter.labReports.isNotEmpty),
      (section: 'Diagnoses', complete: encounter.diagnoses.isNotEmpty),
      (
        section: 'Investigations',
        complete: encounter.investigations.isNotEmpty,
      ),
      (
        section: 'Referral consultations',
        complete: encounter.referralConsultations.isNotEmpty,
      ),
      (
        section: 'Treatment plan',
        complete: encounter.medicalPlan.isNotEmpty ||
            encounter.surgicalPlan.isNotEmpty,
      ),
      (section: 'Advice', complete: encounter.advice.isNotEmpty),
      (
        section: 'Prescriptions',
        complete: encounter.prescriptions.isNotEmpty,
      ),
    ];

    final completedCount = checks.where((c) => c.complete).length;
    final score = ((completedCount / checks.length) * 100).round();
    final missing = checks
        .where((c) => !c.complete)
        .map((c) => c.section)
        .toList(growable: false);
    return (score: score, missingSections: missing);
  }

  void _clearDraftEditor() {
    _draftEncounter = null;
    _draftTranscriptInput = '';
    _draftComplaintsInput = '';
    _draftHistoryInput = '';
    _draftExaminationInput = '';
    _draftClinicalFindingsInput = '';
    _draftVitalsInput = '';
    _draftLabReportsInput = '';
    _draftInvestigationsInput = '';
    _draftReferralsInput = '';
    _draftMedicalPlanInput = '';
    _draftSurgicalPlanInput = '';
    _draftAdviceInput = '';
    _draftDiagnosisInput = '';
    _draftMedicationInput = '';
  }

  Future<void> confirmAndSaveDraft() async {
    if (_draftEncounter == null) {
      _errorMessage = 'No draft encounter available to confirm.';
      notifyListeners();
      return;
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final composed = _composeDraftData(strictValidation: true);
      final encounter = composed.encounter;
      await _encounterRepository.save(encounter);
      await _syncQueueService.enqueue(encounter);
      _latestEncounter = encounter;
      _clinicalWarnings = composed.clinicalWarnings;
      _interactionWarnings = composed.interactionWarnings;
      _history = await _encounterRepository.getAll();
      _clearDraftEditor();
      await _buildFutureInsights(encounter, historySnapshot: _history);
      if (_ehrAutoSyncOnSave) {
        await syncCurrentEncounterToEhr();
      }
    } catch (error) {
      if (error is FormatException) {
        _errorMessage = error.message;
      } else {
        _errorMessage = 'Save failed: $error';
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> syncCurrentEncounterToEhr() async {
    final target = reviewEncounter;
    if (target == null) {
      _ehrStatusMessage = 'No encounter available for EHR sync.';
      notifyListeners();
      return;
    }

    final completeness = _calculateCompleteness(target);
    if (completeness.score < _minimumCompletenessScore) {
      _ehrStatusMessage =
          'EHR sync blocked. Completeness ${completeness.score}% is below $_minimumCompletenessScore%. '
          'Missing: ${completeness.missingSections.join(', ')}.';
      notifyListeners();
      return;
    }

    _isEhrSyncing = true;
    _ehrStatusMessage = null;
    notifyListeners();

    try {
      final options = EhrIntegrationOptions(
        systemType: _ehrSystemType,
        endpointUrl: _ehrEndpoint,
        apiToken: _ehrApiToken,
        includeTranscript: _ehrIncludeTranscript,
        includePdfLink: _ehrIncludePdfLink,
      );
      final result = await _ehrIntegrationService.integrateEncounter(
        target,
        options,
        exportedPdfPath: _lastExportPath,
      );
      _ehrStatusMessage = result.message;
      _lastEhrPayloadPath = result.payloadPath;
    } catch (error) {
      _ehrStatusMessage = 'EHR sync failed: $error';
    } finally {
      _isEhrSyncing = false;
      notifyListeners();
    }
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

  Future<void> exportCurrentEncounter() async {
    final canExport = _draftEncounter != null || _latestEncounter != null;
    if (!canExport) {
      _errorMessage = 'No encounter available for export.';
      notifyListeners();
      return;
    }

    _isExporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Encounter exportTarget;
      if (_draftEncounter != null) {
        final composed = _composeDraftData(strictValidation: true);
        exportTarget = composed.encounter;
        _clinicalWarnings = composed.clinicalWarnings;
        _interactionWarnings = composed.interactionWarnings;
      } else {
        exportTarget = _latestEncounter!;
        final completeness = _calculateCompleteness(exportTarget);
        if (completeness.score < _minimumCompletenessScore) {
          throw FormatException(
            'Completeness score is ${completeness.score}% (minimum $_minimumCompletenessScore%). '
            'Missing: ${completeness.missingSections.join(', ')}.',
          );
        }
      }

      _lastExportPath =
          await _opdSheetExportService.exportEncounterPdf(exportTarget);
    } catch (error) {
      if (error is FormatException) {
        _errorMessage = error.message;
      } else {
        _errorMessage = 'Export failed: $error';
      }
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> exportLatestEncounter() => exportCurrentEncounter();

  Future<void> _runLiveAnalysis(String transcript) async {
    if (_liveAnalysisBusy) {
      return;
    }
    if (transcript.trim().length < 4 ||
        transcript == _lastAnalyzedLiveTranscript) {
      return;
    }

    _liveAnalysisBusy = true;
    try {
      final structured = await _extractionService.extract(transcript);
      final diagnoses = _diagnosisService.suggest(transcript);
      final parse = _prescriptionParserService.parse(transcript);
      _applyStructuredPatientDetails(structured);
      _liveComplaints = structured.chiefComplaints;
      _liveVitals = structured.vitals;
      _liveLabReports = structured.labReports;
      _liveInvestigations = structured.investigations;
      _liveReferrals = structured.referralConsultations;
      _liveMedicalPlan = structured.medicalPlan;
      _liveSurgicalPlan = structured.surgicalPlan;
      _liveAdvice = structured.advice;
      _liveDiagnoses = diagnoses.map((d) => d.name).toList(growable: false);
      _liveDetectedLanguage = structured.detectedLanguage ?? 'Unknown';
      _liveMedicationPreview = parse.rows.isEmpty
          ? 'No medications detected yet.'
          : parse.rows
              .map((p) => '${p.drug} ${p.dose} ${p.frequency} ${p.duration}')
              .join('; ');
      _liveAiReport = _buildLiveAiReport();
      _lastAnalyzedLiveTranscript = transcript;
    } catch (_) {
      // Keep recording loop stable even if a partial transcript causes parsing issues.
    } finally {
      _liveAnalysisBusy = false;
    }
  }

  String _buildLiveAiReport() {
    final language = _liveDetectedLanguage.trim().isEmpty
        ? 'Unknown'
        : _liveDetectedLanguage.trim();
    final complaints = _liveComplaints.isEmpty
        ? 'not yet detected'
        : _liveComplaints.join(', ');
    final vitals =
        _liveVitals.isEmpty ? 'not yet detected' : _liveVitals.join(', ');
    final labs =
        _liveLabReports.isEmpty ? 'none yet' : _liveLabReports.join(', ');
    final dx = _liveDiagnoses.isEmpty
        ? 'awaiting enough context'
        : _liveDiagnoses.join(', ');
    final ix = _liveInvestigations.isEmpty
        ? 'none yet'
        : _liveInvestigations.join(', ');
    final referrals =
        _liveReferrals.isEmpty ? 'none' : _liveReferrals.join(', ');
    final treatment = [
      if (_liveMedicalPlan.isNotEmpty)
        'medical: ${_liveMedicalPlan.join(', ')}',
      if (_liveSurgicalPlan.isNotEmpty)
        'surgical: ${_liveSurgicalPlan.join(', ')}',
      if (_liveAdvice.isNotEmpty) 'advice: ${_liveAdvice.join(', ')}',
    ].join(' | ');
    return 'Live case prep: language [$language], complaints [$complaints], diagnosis candidates [$dx], '
        'vitals [$vitals], labs [$labs], investigations [$ix], referrals [$referrals], '
        'treatment [${treatment.isEmpty ? 'pending' : treatment}], meds [$_liveMedicationPreview].';
  }

  void _autoPopulatePatientFromVoice(
    String transcript, {
    bool notify = true,
  }) {
    final text = transcript.toLowerCase();

    final nameMatch = RegExp(
      r'\b(?:my name is|name is|patient name is|this is)\s+([a-z]+(?:\s+[a-z]+){0,3})',
      caseSensitive: false,
    ).firstMatch(transcript);
    final detectedName = nameMatch?.group(1)?.trim();
    if (detectedName != null && detectedName.isNotEmpty) {
      final titleCaseName = detectedName
          .split(RegExp(r'\s+'))
          .where((e) => e.trim().isNotEmpty)
          .map((e) => '${e[0].toUpperCase()}${e.substring(1).toLowerCase()}')
          .join(' ');
      if (!_patientNameTouched || _patientName.trim().isEmpty) {
        _patientName = titleCaseName;
      }
    }

    final agePatterns = <RegExp>[
      RegExp(r'\b(?:i am|age is|aged?)\s+(\d{1,3})\b', caseSensitive: false),
      RegExp(r'\b(\d{1,3})\s*(?:years?|yrs?)\s*old\b', caseSensitive: false),
    ];
    int? detectedAge;
    for (final pattern in agePatterns) {
      final match = pattern.firstMatch(transcript);
      if (match != null) {
        detectedAge = int.tryParse(match.group(1) ?? '');
        if (detectedAge != null) {
          break;
        }
      }
    }
    if (detectedAge != null && detectedAge > 0 && detectedAge < 130) {
      if (!_patientAgeTouched || _patientAgeInput.trim().isEmpty) {
        _patientAgeInput = detectedAge.toString();
      }
    }

    String? detectedGender;
    if (text.contains('female') || text.contains('woman')) {
      detectedGender = 'Female';
    } else if (text.contains('male') || text.contains('man')) {
      detectedGender = 'Male';
    }
    if (detectedGender != null &&
        (!_patientGenderTouched || _patientGender == 'Unknown')) {
      _patientGender = detectedGender;
    }

    if (notify) {
      notifyListeners();
    }
  }

  void _applyStructuredPatientDetails(StructuredExtraction structured) {
    if (structured.patientName != null &&
        structured.patientName!.trim().isNotEmpty &&
        (!_patientNameTouched || _patientName.trim().isEmpty)) {
      _patientName = structured.patientName!.trim();
    }

    if (structured.patientAge != null &&
        structured.patientAge! > 0 &&
        structured.patientAge! < 130 &&
        (!_patientAgeTouched || _patientAgeInput.trim().isEmpty)) {
      _patientAgeInput = structured.patientAge!.toString();
    }

    if (structured.patientGender != null &&
        (!_patientGenderTouched || _patientGender == 'Unknown')) {
      _patientGender = _normalizeGender(structured.patientGender!);
    }
  }

  void _startMicUiUpdates() {
    _micUiTimer?.cancel();
    _micUiTimer = Timer.periodic(const Duration(milliseconds: 160), (_) {
      _voiceLevel = _audioService.voiceLevel.clamp(0.0, 1.0);
      _isMicChecking = _audioService.isMicCheckInProgress;
      final latestTranscript = _audioService.liveTranscript.trim();
      if (latestTranscript.isNotEmpty && latestTranscript != _liveTranscript) {
        _liveTranscript = latestTranscript;
        _transcript = latestTranscript;
        if (!_liveCorrectionDirty) {
          _liveCorrectionInput = latestTranscript;
        }
        _autoPopulatePatientFromVoice(latestTranscript, notify: false);
      }
      if (_liveTranscript.isNotEmpty) {
        // Keep analysis running in the background against the full transcript
        // even when new text arrives while a previous pass is still running.
        unawaited(_runLiveAnalysis(_liveTranscript));
      }
      notifyListeners();
    });
  }

  void _stopMicUiUpdates() {
    _micUiTimer?.cancel();
    _micUiTimer = null;
    _voiceLevel = 0;
    _isMicChecking = false;
    _liveAnalysisBusy = false;
  }

  @override
  void dispose() {
    _stopMicUiUpdates();
    _audioService.dispose();
    super.dispose();
  }
}
