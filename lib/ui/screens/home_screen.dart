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
          appBar: AppBar(title: const Text('RxNova Clinical AI')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: controller.isBusy ? null : controller.toggleRecording,
            icon: Icon(controller.isRecording ? Icons.stop : Icons.mic),
            label: Text(controller.isRecording ? 'Stop Consultation' : 'Start Consultation'),
          ),
          body: controller.isBusy
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    SectionCard(
                      title: 'Transcript',
                      child: Text(controller.transcript.isEmpty
                          ? 'Tap Start Consultation to simulate offline voice capture.'
                          : controller.transcript),
                    ),
                    if (encounter != null) ...[
                      SectionCard(
                        title: 'Encounter Summary',
                        child: Text('Patient: ${encounter.patient.name}\nCreated: ${formatDateTime(encounter.createdAt)}'),
                      ),
                      SectionCard(
                        title: 'Chief Complaints',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: encounter.chiefComplaints.map((e) => Text('• $e')).toList(growable: false),
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
                              .map((d) => Text('• ${d.name} (${d.icdCode}) - ${(d.confidence * 100).toStringAsFixed(0)}%'))
                              .toList(growable: false),
                        ),
                      ),
                      SectionCard(
                        title: 'Investigations',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: encounter.investigations.map((e) => Text('• $e')).toList(growable: false),
                        ),
                      ),
                      SectionCard(
                        title: 'Prescription',
                        child: PrescriptionTable(rows: encounter.prescriptions),
                      ),
                    ],
                    SectionCard(
                      title: 'Recent Encounters (${controller.history.length})',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: controller.history
                            .map((e) => Text('• ${formatDateTime(e.createdAt)}: ${e.chiefComplaints.join(', ')}'))
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
