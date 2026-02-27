import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_time_utils.dart';
import '../../features/consultation/consultation_controller.dart';
import '../widgets/prescription_table.dart';
import '../widgets/section_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConsultationController>(
      builder: (context, controller, _) {
        final encounter = controller.latestEncounter;

        return Scaffold(
          appBar: AppBar(
            title: const Text('RxNova Clinical AI'),
            actions: [
              IconButton(
                onPressed:
                    controller.isExporting || controller.latestEncounter == null
                        ? null
                        : controller.exportLatestEncounter,
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: controller.isExporting
                    ? 'Exporting OPD sheet...'
                    : 'Export latest OPD sheet (PDF)',
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
                      title: 'Patient Profile',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            initialValue: controller.patientName,
                            decoration: const InputDecoration(
                              labelText: 'Patient name',
                              hintText: 'Enter patient name',
                            ),
                            onChanged: controller.setPatientName,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
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
                          ? 'Tap Start Consultation to simulate offline voice capture.'
                          : controller.transcript),
                    ),
                    if (encounter != null) ...[
                      SectionCard(
                        title: 'Encounter Summary',
                        child: Text(
                          'Patient: ${encounter.patient.name}\nCreated: ${formatDateTime(encounter.createdAt)}\nNeeds review: ${encounter.requiresClinicalReview ? 'Yes' : 'No'}',
                        ),
                      ),
                      if (controller.clinicalWarnings.isNotEmpty)
                        SectionCard(
                          title: 'Clinical Warnings',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: controller.clinicalWarnings
                                .map((e) => Text('• $e'))
                                .toList(growable: false),
                          ),
                        ),
                      SectionCard(
                        title: 'Chief Complaints',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: encounter.chiefComplaints
                              .map((e) => Text('• $e'))
                              .toList(growable: false),
                        ),
                      ),
                      SectionCard(
                        title: 'Examination',
                        child: Text(encounter.examination),
                      ),
                      SectionCard(
                        title: 'Diagnosis Suggestions',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: encounter.diagnoses
                              .map(
                                (d) => Text(
                                  '• ${d.name} (${d.icdCode}) - ${(d.confidence * 100).toStringAsFixed(0)}%${d.requiresConfirmation ? ' [Confirm]' : ''}',
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                      SectionCard(
                        title: 'Investigations',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: encounter.investigations
                              .map((e) => Text('• $e'))
                              .toList(growable: false),
                        ),
                      ),
                      SectionCard(
                        title: 'Prescription',
                        child: PrescriptionTable(rows: encounter.prescriptions),
                      ),
                      if (controller.interactionWarnings.isNotEmpty)
                        SectionCard(
                          title: 'Drug Interaction Warnings',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: controller.interactionWarnings
                                .map((e) => Text('• $e'))
                                .toList(growable: false),
                          ),
                        ),
                    ],
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
}
