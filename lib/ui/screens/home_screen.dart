import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_time_utils.dart';
import '../../data/models/encounter.dart';
import '../../features/consultation/consultation_controller.dart';
import '../../services/ehr_service/ehr_integration_service.dart';
import '../widgets/section_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConsultationController>(
      builder: (context, controller, _) {
        final encounter = controller.reviewEncounter;

        return Scaffold(
          appBar: AppBar(
            title: const Text('RxNova Clinical AI'),
            actions: [
              IconButton(
                onPressed:
                    controller.isExporting || controller.reviewEncounter == null
                        ? null
                        : controller.exportCurrentEncounter,
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: controller.isExporting
                    ? 'Exporting OPD sheet...'
                    : 'Export current OPD sheet (PDF)',
              ),
              IconButton(
                onPressed:
                    controller.isSyncing ? null : controller.flushSyncQueue,
                icon: const Icon(Icons.sync),
                tooltip:
                    'Sync pending encounters (${controller.pendingSyncCount})',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: controller.isBusy ? null : controller.toggleRecording,
            icon: Icon(controller.isRecording ? Icons.stop : Icons.mic),
            label: Text(controller.isRecording
                ? 'Stop Consultation'
                : 'Start Consultation'),
          ),
          body: controller.isBusy
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (controller.errorMessage != null)
                      SectionCard(
                        title: 'Error',
                        child: Text(controller.errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    if (controller.lastExportPath != null)
                      SectionCard(
                        title: 'Last Export',
                        child: Text(controller.lastExportPath!),
                      ),
                    SectionCard(
                      title: 'Completeness Gate',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Score: ${controller.completenessScore}% (minimum ${controller.minimumCompletenessScore}%)'),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: controller.completenessScore / 100,
                            minHeight: 8,
                            color: controller.isCompletenessPassed
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          Text(controller.isCompletenessPassed
                              ? 'Mandatory documentation threshold met.'
                              : 'Save/export/EHR sync will be blocked until threshold is met.'),
                          if (controller
                              .missingMandatorySections.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...controller.missingMandatorySections
                                .map((m) => Text('Missing: $m')),
                          ],
                        ],
                      ),
                    ),
                    SectionCard(
                      title: 'Patient Profile',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            key: ValueKey(
                                'patient-name-${controller.patientName}'),
                            initialValue: controller.patientName,
                            decoration: const InputDecoration(
                              labelText: 'Patient name',
                              hintText: 'Enter patient name',
                            ),
                            onChanged: controller.setPatientName,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: ValueKey(
                                'patient-age-${controller.patientAgeInput}'),
                            initialValue: controller.patientAgeInput,
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              hintText: 'Enter age',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: controller.setPatientAgeInput,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                                'patient-gender-${controller.patientGender}'),
                            initialValue: controller.patientGender,
                            items: const [
                              DropdownMenuItem(
                                  value: 'Unknown', child: Text('Unknown')),
                              DropdownMenuItem(
                                  value: 'Male', child: Text('Male')),
                              DropdownMenuItem(
                                  value: 'Female', child: Text('Female')),
                              DropdownMenuItem(
                                  value: 'Other', child: Text('Other')),
                            ],
                            decoration:
                                const InputDecoration(labelText: 'Gender'),
                            onChanged: (value) {
                              if (value != null) {
                                controller.setPatientGender(value);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: ValueKey(
                                'patient-allergies-${controller.allergiesInput}'),
                            initialValue: controller.allergiesInput,
                            decoration: const InputDecoration(
                              labelText: 'Allergies',
                              hintText:
                                  'Comma-separated, e.g. ibuprofen, penicillin',
                            ),
                            onChanged: controller.setAllergiesInput,
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Pregnancy risk context'),
                            value: controller.isPregnant,
                            onChanged: controller.setPregnancyStatus,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Renal risk context'),
                            value: controller.hasRenalRisk,
                            onChanged: controller.setRenalRisk,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Hepatic risk context'),
                            value: controller.hasHepaticRisk,
                            onChanged: controller.setHepaticRisk,
                          ),
                        ],
                      ),
                    ),
                    SectionCard(
                      title: 'Transcript',
                      child: Text(controller.transcript.isEmpty
                          ? 'Tap Start Consultation and speak clearly for live transcription.'
                          : controller.transcript),
                    ),
                    SectionCard(
                      title: 'Mic Status',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.isRecording
                                ? (controller.isMicChecking
                                    ? 'Mic check in progress...'
                                    : 'Mic active and listening (live analysis enabled)')
                                : 'Mic idle',
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 10,
                              value: controller.voiceLevel,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              'Voice level: ${(controller.voiceLevel * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    ),
                    SectionCard(
                      title: 'Live Voice Analysis',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(controller.liveTranscript.isEmpty
                              ? 'Start recording and speak patient details (name, age, gender) and symptoms.'
                              : 'Live transcript (full conversation): ${controller.liveTranscript}'),
                          const SizedBox(height: 8),
                          Text(
                              'Detected language: ${controller.liveDetectedLanguage}'),
                          const SizedBox(height: 4),
                          Text(
                              'Detected complaints: ${controller.liveComplaints.isEmpty ? 'None yet' : controller.liveComplaints.join(', ')}'),
                          const SizedBox(height: 4),
                          Text(
                              'Diagnosis candidates: ${controller.liveDiagnoses.isEmpty ? 'None yet' : controller.liveDiagnoses.join(', ')}'),
                          const SizedBox(height: 4),
                          Text(
                              'Suggested investigations: ${controller.liveInvestigations.isEmpty ? 'None yet' : controller.liveInvestigations.join(', ')}'),
                          const SizedBox(height: 4),
                          Text(
                              'Vitals: ${controller.liveVitals.isEmpty ? 'None yet' : controller.liveVitals.join(', ')}'),
                          const SizedBox(height: 4),
                          Text(
                              'Lab reports: ${controller.liveLabReports.isEmpty ? 'None yet' : controller.liveLabReports.join(', ')}'),
                          const SizedBox(height: 4),
                          Text(
                              'Referrals: ${controller.liveReferrals.isEmpty ? 'None yet' : controller.liveReferrals.join(', ')}'),
                          const SizedBox(height: 4),
                          Text(
                              'Medical plan: ${controller.liveMedicalPlan.isEmpty ? 'None yet' : controller.liveMedicalPlan.join(', ')}'),
                          const SizedBox(height: 4),
                          Text(
                              'Surgical plan: ${controller.liveSurgicalPlan.isEmpty ? 'None yet' : controller.liveSurgicalPlan.join(', ')}'),
                          const SizedBox(height: 4),
                          Text(
                              'Advice: ${controller.liveAdvice.isEmpty ? 'None yet' : controller.liveAdvice.join(', ')}'),
                          const SizedBox(height: 4),
                          Text(
                              'Medication preview: ${controller.liveMedicationPreview.isEmpty ? 'None yet' : controller.liveMedicationPreview}'),
                          const SizedBox(height: 8),
                          Text(controller.liveAiReport),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: ValueKey(
                                'live-correction-${controller.liveCorrectionInput}'),
                            initialValue: controller.liveCorrectionInput,
                            decoration: const InputDecoration(
                              labelText: 'Correct live transcript errors',
                              hintText:
                                  'Edit recognized text and apply correction',
                            ),
                            minLines: 2,
                            maxLines: 4,
                            onChanged: controller.setLiveCorrectionInput,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: controller.isRecording
                                    ? controller.applyLiveCorrection
                                    : null,
                                icon: const Icon(Icons.auto_fix_high),
                                label: const Text('Apply Live Correction'),
                              ),
                              TextButton.icon(
                                onPressed: controller.isRecording
                                    ? controller.resetLiveCorrection
                                    : null,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reset To Live Feed'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SectionCard(
                      title: 'Single Page Case Sheet',
                      child: _buildSinglePageCaseSheet(
                          context, controller, encounter),
                    ),
                    SectionCard(
                      title: 'Copilot Explainability',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Template suggestion: ${controller.copilotExplainability.templateSuggestion}'),
                          const SizedBox(height: 6),
                          Text(
                              'Why this suggestion: ${controller.copilotExplainability.rationale}'),
                          if (controller.copilotExplainability.evidenceSignals
                              .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...controller.copilotExplainability.evidenceSignals
                                .map((e) => Text('Evidence: $e')),
                          ],
                          if (controller.copilotExplainability.doctorMacros
                              .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...controller.copilotExplainability.doctorMacros
                                .map((e) => Text('Macro: $e')),
                          ],
                        ],
                      ),
                    ),
                    SectionCard(
                      title: 'Futuristic Intelligence Suite',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Personalized template: ${controller.futureInsights.personalizedTemplate}'),
                          const SizedBox(height: 6),
                          Text(
                              'Longitudinal: ${controller.futureInsights.longitudinalSummary}'),
                          const SizedBox(height: 6),
                          Text(
                              'Federated status: ${controller.futureInsights.federatedStatus}'),
                          const SizedBox(height: 6),
                          Text(
                              'Multimodal: ${controller.futureInsights.multimodalSummary}'),
                          const SizedBox(height: 6),
                          Text(
                              'Coding & billing: ${controller.futureInsights.billingSummary}'),
                          const SizedBox(height: 6),
                          Text(
                              'Population signal: ${controller.futureInsights.populationSignal}'),
                          const SizedBox(height: 6),
                          Text(
                              'Digital twin: ${controller.futureInsights.digitalTwinPlan}'),
                          if (controller
                              .futureInsights.voiceActions.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...controller.futureInsights.voiceActions
                                .map((e) => Text('Voice action: $e')),
                          ],
                          if (controller
                              .futureInsights.safetyAlerts.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...controller.futureInsights.safetyAlerts
                                .map((e) => Text('Safety: $e')),
                          ],
                          if (controller
                              .futureInsights.qaFindings.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...controller.futureInsights.qaFindings
                                .map((e) => Text('QA: $e')),
                          ],
                        ],
                      ),
                    ),
                    SectionCard(
                      title: 'EHR Integration',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue:
                                controller.ehrSystemType == EhrSystemType.fhirR4
                                    ? 'FHIR R4'
                                    : controller.ehrSystemType ==
                                            EhrSystemType.hl7v2Bridge
                                        ? 'HL7v2 Bridge'
                                        : 'Custom API',
                            items: const [
                              DropdownMenuItem(
                                  value: 'FHIR R4', child: Text('FHIR R4')),
                              DropdownMenuItem(
                                  value: 'HL7v2 Bridge',
                                  child: Text('HL7v2 Bridge')),
                              DropdownMenuItem(
                                  value: 'Custom API',
                                  child: Text('Custom API')),
                            ],
                            decoration:
                                const InputDecoration(labelText: 'EHR target'),
                            onChanged: (value) {
                              if (value == null) return;
                              if (value == 'FHIR R4') {
                                controller
                                    .setEhrSystemType(EhrSystemType.fhirR4);
                              } else if (value == 'HL7v2 Bridge') {
                                controller.setEhrSystemType(
                                    EhrSystemType.hl7v2Bridge);
                              } else {
                                controller
                                    .setEhrSystemType(EhrSystemType.customApi);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: ValueKey(
                                'ehr-endpoint-${controller.ehrEndpoint}'),
                            initialValue: controller.ehrEndpoint,
                            decoration: const InputDecoration(
                              labelText: 'Endpoint URL (optional)',
                              hintText: 'https://ehr.example.com/api/ingest',
                            ),
                            onChanged: controller.setEhrEndpoint,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key:
                                ValueKey('ehr-token-${controller.ehrApiToken}'),
                            initialValue: controller.ehrApiToken,
                            decoration: const InputDecoration(
                              labelText: 'API token (optional)',
                            ),
                            onChanged: controller.setEhrApiToken,
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Include transcript'),
                            value: controller.ehrIncludeTranscript,
                            onChanged: controller.setEhrIncludeTranscript,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Include PDF path'),
                            value: controller.ehrIncludePdfLink,
                            onChanged: controller.setEhrIncludePdfLink,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Auto-sync on save'),
                            value: controller.ehrAutoSyncOnSave,
                            onChanged: controller.setEhrAutoSyncOnSave,
                          ),
                          const SizedBox(height: 6),
                          ElevatedButton.icon(
                            onPressed: controller.isEhrSyncing ||
                                    !controller.isCompletenessPassed
                                ? null
                                : controller.syncCurrentEncounterToEhr,
                            icon: const Icon(Icons.cloud_upload),
                            label: Text(controller.isEhrSyncing
                                ? 'Syncing...'
                                : 'Sync Current Encounter To EHR'),
                          ),
                          if (controller.ehrStatusMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(controller.ehrStatusMessage!),
                          ],
                          if (controller.lastEhrPayloadPath != null) ...[
                            const SizedBox(height: 6),
                            Text('Payload: ${controller.lastEhrPayloadPath!}'),
                          ],
                        ],
                      ),
                    ),
                    SectionCard(
                      title: 'Recent Encounters (${controller.history.length})',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: controller.history
                            .map((e) => Text(
                                '• ${formatDateTime(e.createdAt)}: ${e.chiefComplaints.join(', ')}'))
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSinglePageCaseSheet(
    BuildContext context,
    ConsultationController controller,
    Encounter? encounter,
  ) {
    if (controller.hasDraft) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All clinical data is on this single page for direct editing and future reuse.',
          ),
          const SizedBox(height: 10),
          _heading(context, 'Complaints'),
          _editableField(
            key: 'draft-complaints',
            value: controller.draftComplaintsInput,
            hint: 'Comma-separated complaints',
            onChanged: controller.setDraftComplaintsInput,
          ),
          _heading(context, 'Clinical History'),
          _editableField(
            key: 'draft-history',
            value: controller.draftHistoryInput,
            hint: 'History narrative',
            minLines: 2,
            maxLines: 4,
            onChanged: controller.setDraftHistoryInput,
          ),
          _heading(context, 'Clinical Findings'),
          _editableField(
            key: 'draft-findings',
            value: controller.draftClinicalFindingsInput,
            hint: 'Clinical findings',
            minLines: 2,
            maxLines: 4,
            onChanged: controller.setDraftClinicalFindingsInput,
          ),
          _heading(context, 'Vitals'),
          _editableField(
            key: 'draft-vitals',
            value: controller.draftVitalsInput,
            hint: 'e.g. BP:120/80, Pulse:96/min',
            onChanged: controller.setDraftVitalsInput,
          ),
          _heading(context, 'Lab Reports'),
          _editableField(
            key: 'draft-labs',
            value: controller.draftLabReportsInput,
            hint: 'Lab results summary',
            onChanged: controller.setDraftLabReportsInput,
          ),
          _heading(context, 'Provisional Diagnosis'),
          _editableField(
            key: 'draft-diagnosis',
            value: controller.draftDiagnosisInput,
            hint: 'Comma-separated diagnoses',
            onChanged: controller.setDraftDiagnosisInput,
          ),
          _heading(context, 'Investigations'),
          _editableField(
            key: 'draft-investigations',
            value: controller.draftInvestigationsInput,
            hint: 'Ordered investigations',
            onChanged: controller.setDraftInvestigationsInput,
          ),
          _heading(context, 'Referral Consultations'),
          _editableField(
            key: 'draft-referrals',
            value: controller.draftReferralsInput,
            hint: 'Department consultations',
            onChanged: controller.setDraftReferralsInput,
          ),
          _heading(context, 'Treatment Plan - Medical'),
          _editableField(
            key: 'draft-medical-plan',
            value: controller.draftMedicalPlanInput,
            hint: 'Medical management options',
            onChanged: controller.setDraftMedicalPlanInput,
          ),
          _heading(context, 'Treatment Plan - Surgical'),
          _editableField(
            key: 'draft-surgical-plan',
            value: controller.draftSurgicalPlanInput,
            hint: 'Surgical options',
            onChanged: controller.setDraftSurgicalPlanInput,
          ),
          _heading(context, 'Advice'),
          _editableField(
            key: 'draft-advice',
            value: controller.draftAdviceInput,
            hint: 'Patient advice',
            onChanged: controller.setDraftAdviceInput,
          ),
          _heading(context, 'Prescriptions'),
          _editableField(
            key: 'draft-meds',
            value: controller.draftMedicationInput,
            hint: 'Medication instructions',
            minLines: 2,
            maxLines: 4,
            onChanged: controller.setDraftMedicationInput,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: controller.isBusy || !controller.isCompletenessPassed
                    ? null
                    : controller.confirmAndSaveDraft,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm And Save OPD Sheet'),
              ),
              OutlinedButton.icon(
                onPressed:
                    controller.isExporting || !controller.isCompletenessPassed
                        ? null
                        : controller.exportCurrentEncounter,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export Edited Draft PDF'),
              ),
            ],
          ),
          if (controller.clinicalWarnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            _heading(context, 'Clinical Warnings'),
            ...controller.clinicalWarnings.map((w) => Text('• $w')),
          ],
          if (controller.interactionWarnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            _heading(context, 'Drug Interaction Warnings'),
            ...controller.interactionWarnings.map((w) => Text('• $w')),
          ],
        ],
      );
    }

    if (encounter == null) {
      return const Text(
          'No case sheet available yet. Start consultation to generate data.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patient: ${encounter.patient.name} | ${encounter.patient.age} | ${encounter.patient.gender}',
        ),
        const SizedBox(height: 8),
        _heading(context, 'Complaints'),
        Text(encounter.chiefComplaints.isEmpty
            ? 'None'
            : encounter.chiefComplaints.join(', ')),
        _heading(context, 'Clinical History'),
        Text(encounter.history.isEmpty ? 'None' : encounter.history),
        _heading(context, 'Clinical Findings'),
        Text(encounter.clinicalFindings.isEmpty
            ? 'None'
            : encounter.clinicalFindings),
        _heading(context, 'Vitals'),
        Text(encounter.vitals.isEmpty ? 'None' : encounter.vitals.join(', ')),
        _heading(context, 'Lab Reports'),
        Text(encounter.labReports.isEmpty
            ? 'None'
            : encounter.labReports.join(', ')),
        _heading(context, 'Provisional Diagnosis'),
        Text(encounter.diagnoses.isEmpty
            ? 'None'
            : encounter.diagnoses
                .map((d) => '${d.name} (${d.icdCode})')
                .join(', ')),
        _heading(context, 'Investigations'),
        Text(encounter.investigations.isEmpty
            ? 'None'
            : encounter.investigations.join(', ')),
        _heading(context, 'Referral Consultations'),
        Text(encounter.referralConsultations.isEmpty
            ? 'None'
            : encounter.referralConsultations.join(', ')),
        _heading(context, 'Treatment Plan'),
        Text(
            'Medical: ${encounter.medicalPlan.isEmpty ? 'None' : encounter.medicalPlan.join(', ')}\n'
            'Surgical: ${encounter.surgicalPlan.isEmpty ? 'None' : encounter.surgicalPlan.join(', ')}\n'
            'Advice: ${encounter.advice.isEmpty ? 'None' : encounter.advice.join(', ')}'),
        _heading(context, 'Prescriptions'),
        Text(encounter.prescriptions.isEmpty
            ? 'None'
            : encounter.prescriptions
                .map((p) =>
                    '${p.drug} ${p.dose}, ${p.frequency}, ${p.duration}, ${p.route}')
                .join('\n')),
      ],
    );
  }

  Widget _heading(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _editableField({
    required String key,
    required String value,
    required String hint,
    required ValueChanged<String> onChanged,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextFormField(
      key: ValueKey(key),
      initialValue: value,
      decoration: InputDecoration(hintText: hint),
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
    );
  }
}
