import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/models/encounter.dart';

enum EhrSystemType {
  fhirR4,
  hl7v2Bridge,
  customApi,
}

class EhrIntegrationOptions {
  const EhrIntegrationOptions({
    required this.systemType,
    required this.endpointUrl,
    required this.apiToken,
    required this.includeTranscript,
    required this.includePdfLink,
  });

  final EhrSystemType systemType;
  final String endpointUrl;
  final String apiToken;
  final bool includeTranscript;
  final bool includePdfLink;
}

class EhrIntegrationResult {
  const EhrIntegrationResult({
    required this.success,
    required this.message,
    this.payloadPath,
    this.remoteStatusCode,
  });

  final bool success;
  final String message;
  final String? payloadPath;
  final int? remoteStatusCode;
}

class EhrIntegrationService {
  const EhrIntegrationService({this.baseDirectoryPath});

  final String? baseDirectoryPath;

  Future<EhrIntegrationResult> integrateEncounter(
    Encounter encounter,
    EhrIntegrationOptions options, {
    String? exportedPdfPath,
  }) async {
    final payload =
        _buildPayload(encounter, options, exportedPdfPath: exportedPdfPath);
    final payloadPath =
        await _savePayload(payload, encounter.id, options.systemType);

    final endpoint = options.endpointUrl.trim();
    if (endpoint.isEmpty) {
      return EhrIntegrationResult(
        success: true,
        message: 'EHR payload prepared locally (no endpoint configured).',
        payloadPath: payloadPath,
      );
    }

    try {
      final uri = Uri.parse(endpoint);
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      if (options.apiToken.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader,
            'Bearer ${options.apiToken.trim()}');
      }
      request.write(jsonEncode(payload));
      final response = await request.close();
      final statusCode = response.statusCode;
      await response.drain();
      client.close(force: true);

      final ok = statusCode >= 200 && statusCode < 300;
      return EhrIntegrationResult(
        success: ok,
        message: ok
            ? 'EHR sync successful.'
            : 'EHR endpoint returned HTTP $statusCode. Payload saved locally.',
        payloadPath: payloadPath,
        remoteStatusCode: statusCode,
      );
    } catch (error) {
      return EhrIntegrationResult(
        success: false,
        message: 'EHR sync failed: $error. Payload saved locally.',
        payloadPath: payloadPath,
      );
    }
  }

  Map<String, dynamic> _buildPayload(
    Encounter encounter,
    EhrIntegrationOptions options, {
    String? exportedPdfPath,
  }) {
    switch (options.systemType) {
      case EhrSystemType.fhirR4:
        return _buildFhirPayload(encounter, options,
            exportedPdfPath: exportedPdfPath);
      case EhrSystemType.hl7v2Bridge:
        return _buildHl7BridgePayload(encounter, options,
            exportedPdfPath: exportedPdfPath);
      case EhrSystemType.customApi:
        return _buildCustomPayload(encounter, options,
            exportedPdfPath: exportedPdfPath);
    }
  }

  Map<String, dynamic> _buildFhirPayload(
    Encounter encounter,
    EhrIntegrationOptions options, {
    String? exportedPdfPath,
  }) {
    final entries = <Map<String, dynamic>>[];

    entries.add({
      'resource': {
        'resourceType': 'Patient',
        'id': encounter.patient.id,
        'name': [
          {'text': encounter.patient.name}
        ],
        'gender': encounter.patient.gender.toLowerCase() == 'male'
            ? 'male'
            : encounter.patient.gender.toLowerCase() == 'female'
                ? 'female'
                : 'unknown',
        'birthDate': null,
        'extension': [
          if (encounter.patient.allergies.isNotEmpty)
            {
              'url': 'http://rxnova.ai/fhir/StructureDefinition/allergies',
              'valueString': encounter.patient.allergies.join(', '),
            },
          {
            'url': 'http://rxnova.ai/fhir/StructureDefinition/risk-profile',
            'valueString':
                'pregnant=${encounter.patient.isPregnant}, renalRisk=${encounter.patient.hasRenalRisk}, hepaticRisk=${encounter.patient.hasHepaticRisk}',
          },
        ],
      }
    });

    entries.add({
      'resource': {
        'resourceType': 'Encounter',
        'id': encounter.id,
        'status': 'finished',
        'period': {'start': encounter.createdAt.toIso8601String()},
        'reasonCode': encounter.chiefComplaints
            .map((c) => {'text': c})
            .toList(growable: false),
      }
    });

    for (final diagnosis in encounter.diagnoses) {
      entries.add({
        'resource': {
          'resourceType': 'Condition',
          'code': {
            'text': diagnosis.name,
            'coding': [
              {
                'system': 'http://hl7.org/fhir/sid/icd-10',
                'code': diagnosis.icdCode
              }
            ],
          },
        }
      });
    }

    for (final vital in encounter.vitals) {
      entries.add({
        'resource': {
          'resourceType': 'Observation',
          'status': 'final',
          'category': [
            {'text': 'vital-signs'}
          ],
          'valueString': vital,
        }
      });
    }

    for (final lab in encounter.labReports) {
      entries.add({
        'resource': {
          'resourceType': 'Observation',
          'status': 'final',
          'category': [
            {'text': 'laboratory'}
          ],
          'valueString': lab,
        }
      });
    }

    for (final investigation in encounter.investigations) {
      entries.add({
        'resource': {
          'resourceType': 'ServiceRequest',
          'status': 'active',
          'intent': 'order',
          'code': {'text': investigation},
        }
      });
    }

    for (final prescription in encounter.prescriptions) {
      entries.add({
        'resource': {
          'resourceType': 'MedicationRequest',
          'status': 'active',
          'intent': 'order',
          'medicationCodeableConcept': {'text': prescription.drug},
          'dosageInstruction': [
            {
              'text':
                  '${prescription.dose}, ${prescription.frequency}, ${prescription.duration}, ${prescription.route}',
            }
          ],
        }
      });
    }

    entries.add({
      'resource': {
        'resourceType': 'CarePlan',
        'status': 'active',
        'intent': 'plan',
        'description': [
          'Medical: ${encounter.medicalPlan.join(', ')}',
          'Surgical: ${encounter.surgicalPlan.join(', ')}',
          'Advice: ${encounter.advice.join(', ')}',
          if (encounter.referralConsultations.isNotEmpty)
            'Referrals: ${encounter.referralConsultations.join(', ')}',
        ].join(' | '),
      }
    });

    if (options.includeTranscript && encounter.transcript.trim().isNotEmpty) {
      entries.add({
        'resource': {
          'resourceType': 'DocumentReference',
          'status': 'current',
          'description': 'Encounter transcript',
          'content': [
            {
              'attachment': {
                'contentType': 'text/plain',
                'data': base64Encode(utf8.encode(encounter.transcript))
              }
            }
          ],
        }
      });
    }

    if (options.includePdfLink &&
        exportedPdfPath != null &&
        exportedPdfPath.trim().isNotEmpty) {
      entries.add({
        'resource': {
          'resourceType': 'DocumentReference',
          'status': 'current',
          'description': 'OPD PDF',
          'content': [
            {
              'attachment': {'url': exportedPdfPath}
            }
          ],
        }
      });
    }

    return {
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': entries,
    };
  }

  Map<String, dynamic> _buildHl7BridgePayload(
    Encounter encounter,
    EhrIntegrationOptions options, {
    String? exportedPdfPath,
  }) {
    return {
      'format': 'HL7v2-bridge',
      'patient': {
        'id': encounter.patient.id,
        'name': encounter.patient.name,
        'age': encounter.patient.age,
        'gender': encounter.patient.gender,
      },
      'visit': {
        'encounterId': encounter.id,
        'datetime': encounter.createdAt.toIso8601String(),
        'complaints': encounter.chiefComplaints,
        'findings': encounter.clinicalFindings,
        'vitals': encounter.vitals,
        'labs': encounter.labReports,
        'diagnoses': encounter.diagnoses
            .map((d) => '${d.name} (${d.icdCode})')
            .toList(growable: false),
        'orders': encounter.investigations,
        'referrals': encounter.referralConsultations,
        'plan': {
          'medical': encounter.medicalPlan,
          'surgical': encounter.surgicalPlan,
          'advice': encounter.advice,
        },
        'prescriptions': encounter.prescriptions
            .map((p) =>
                '${p.drug}|${p.dose}|${p.frequency}|${p.duration}|${p.route}')
            .toList(growable: false),
      },
      if (options.includeTranscript) 'transcript': encounter.transcript,
      if (options.includePdfLink && exportedPdfPath != null)
        'pdfPath': exportedPdfPath,
    };
  }

  Map<String, dynamic> _buildCustomPayload(
    Encounter encounter,
    EhrIntegrationOptions options, {
    String? exportedPdfPath,
  }) {
    return {
      'encounterId': encounter.id,
      'createdAt': encounter.createdAt.toIso8601String(),
      'patient': {
        'id': encounter.patient.id,
        'name': encounter.patient.name,
        'age': encounter.patient.age,
        'gender': encounter.patient.gender,
        'allergies': encounter.patient.allergies,
        'riskProfile': {
          'pregnant': encounter.patient.isPregnant,
          'renalRisk': encounter.patient.hasRenalRisk,
          'hepaticRisk': encounter.patient.hasHepaticRisk,
        },
      },
      'clinicalData': {
        'complaints': encounter.chiefComplaints,
        'history': encounter.history,
        'examination': encounter.examination,
        'clinicalFindings': encounter.clinicalFindings,
        'vitals': encounter.vitals,
        'labReports': encounter.labReports,
        'diagnoses': encounter.diagnoses
            .map((d) => {
                  'name': d.name,
                  'icdCode': d.icdCode,
                  'confidence': d.confidence
                })
            .toList(growable: false),
        'investigations': encounter.investigations,
        'referrals': encounter.referralConsultations,
        'treatmentPlan': {
          'medical': encounter.medicalPlan,
          'surgical': encounter.surgicalPlan,
          'advice': encounter.advice,
        },
        'prescriptions': encounter.prescriptions
            .map((p) => p.toMap())
            .toList(growable: false),
      },
      if (options.includeTranscript) 'transcript': encounter.transcript,
      if (options.includePdfLink && exportedPdfPath != null)
        'opdPdfPath': exportedPdfPath,
    };
  }

  Future<String> _savePayload(
    Map<String, dynamic> payload,
    String encounterId,
    EhrSystemType systemType,
  ) async {
    final baseDir = await _resolveBaseDirectory();
    final exportDir = Directory(p.join(baseDir.path, 'ehr_exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final systemName = switch (systemType) {
      EhrSystemType.fhirR4 => 'fhir',
      EhrSystemType.hl7v2Bridge => 'hl7',
      EhrSystemType.customApi => 'custom',
    };
    final filePath = p.join(
        exportDir.path, 'ehr_${encounterId}_${systemName}_$timestamp.json');
    final file = File(filePath);
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true);
    return file.path;
  }

  Future<Directory> _resolveBaseDirectory() async {
    if (baseDirectoryPath != null && baseDirectoryPath!.trim().isNotEmpty) {
      return Directory(baseDirectoryPath!);
    }
    return getApplicationDocumentsDirectory();
  }
}
