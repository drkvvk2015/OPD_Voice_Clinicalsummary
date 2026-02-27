import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/encounter.dart';

class OpdSheetExportService {
  const OpdSheetExportService({this.baseDirectoryPath});

  final String? baseDirectoryPath;

  Future<String> exportEncounterPdf(Encounter encounter) async {
    final directory = await _resolveBaseDirectory();
    final exportDirectory = Directory(p.join(directory.path, 'exports'));
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }

    final safeTimestamp =
        encounter.createdAt.toIso8601String().replaceAll(':', '-');
    final fileName = 'opd_${encounter.id}_$safeTimestamp.pdf';
    final filePath = p.join(exportDirectory.path, fileName);

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'RxNova Clinical AI - OPD Sheet',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Encounter ID: ${encounter.id}'),
          pw.Text('Date: ${encounter.createdAt.toIso8601String()}'),
          pw.Text(
              'Patient: ${encounter.patient.name} (${encounter.patient.age}, ${encounter.patient.gender})'),
          _section('Patient Risk Profile', [
            if (encounter.patient.allergies.isNotEmpty)
              'Allergies: ${encounter.patient.allergies.join(', ')}'
            else
              'Allergies: none reported',
            'Pregnancy context: ${encounter.patient.isPregnant ? 'Yes' : 'No'}',
            'Renal risk: ${encounter.patient.hasRenalRisk ? 'Yes' : 'No'}',
            'Hepatic risk: ${encounter.patient.hasHepaticRisk ? 'Yes' : 'No'}',
          ]),
          pw.SizedBox(height: 12),
          _section('Chief Complaints', encounter.chiefComplaints),
          _section('History', [encounter.history]),
          _section('Examination', [encounter.examination]),
          _section(
            'Diagnoses',
            encounter.diagnoses
                .map(
                  (d) =>
                      '${d.name} (${d.icdCode}) | Confidence ${(d.confidence * 100).toStringAsFixed(0)}%'
                      '${d.requiresConfirmation ? ' [Confirm]' : ''}',
                )
                .toList(growable: false),
          ),
          _section('Investigations', encounter.investigations),
          _section(
            'Prescriptions',
            encounter.prescriptions
                .map((p) =>
                    '${p.drug} ${p.dose}, ${p.frequency}, ${p.duration}, ${p.route}')
                .toList(growable: false),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            encounter.requiresClinicalReview
                ? 'Clinical review required before final sign-off.'
                : 'No review flag set.',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: encounter.requiresClinicalReview
                  ? PdfColors.red700
                  : PdfColors.green700,
            ),
          ),
        ],
      ),
    );

    final file = File(filePath);
    await file.writeAsBytes(await document.save(), flush: true);
    return file.path;
  }

  Future<Directory> _resolveBaseDirectory() async {
    if (baseDirectoryPath != null && baseDirectoryPath!.trim().isNotEmpty) {
      return Directory(baseDirectoryPath!);
    }
    return getApplicationDocumentsDirectory();
  }

  pw.Widget _section(String title, List<String> lines) {
    final normalized =
        lines.where((line) => line.trim().isNotEmpty).toList(growable: false);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        if (normalized.isEmpty)
          pw.Text('- None')
        else
          ...normalized.map((line) => pw.Text('- $line')),
        pw.SizedBox(height: 8),
      ],
    );
  }
}
