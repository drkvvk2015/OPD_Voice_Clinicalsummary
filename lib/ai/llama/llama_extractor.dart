import '../../ai/contracts/llama_adapter.dart';
import '../../services/extraction_service/structured_extraction.dart';

class LlamaExtractor implements LlamaAdapter {
  @override
  Future<StructuredExtraction> extract(String transcript) async {
    final lower = transcript.toLowerCase();

    final complaints = _extractComplaints(lower);
    final investigations = _extractInvestigations(lower);
    final vitals = _extractVitals(transcript);
    final labReports = _extractLabReports(transcript);
    final referrals = _extractReferrals(lower);
    final medicalPlan = _extractMedicalPlan(lower);
    final surgicalPlan = _extractSurgicalPlan(lower);
    final advice = _extractAdvice(lower);

    final patientName = _extractPatientName(transcript);
    final patientAge = _extractPatientAge(transcript);
    final patientGender = _extractPatientGender(lower);

    final clinicalFindings = _extractClinicalFindings(lower);
    final examination = clinicalFindings.isEmpty
        ? 'General physical examination captured.'
        : clinicalFindings;

    final warnings = <String>[];
    if (vitals.isEmpty) {
      warnings.add(
          'Vitals incomplete: no explicit BP/pulse/temperature/SpO2 detected.');
    }
    if (medicalPlan.isEmpty && surgicalPlan.isEmpty) {
      warnings.add('Treatment plan not clearly captured from transcript.');
    }

    return StructuredExtraction(
      chiefComplaints: complaints,
      history: transcript,
      examination: examination,
      clinicalFindings: clinicalFindings,
      vitals: vitals,
      labReports: labReports,
      investigations: investigations,
      referralConsultations: referrals,
      medicalPlan: medicalPlan,
      surgicalPlan: surgicalPlan,
      advice: advice,
      warnings: warnings,
      patientName: patientName,
      patientAge: patientAge,
      patientGender: patientGender,
    );
  }

  List<String> _extractComplaints(String lower) {
    final complaints = <String>[
      if (lower.contains('fever')) 'Fever',
      if (lower.contains('cough')) 'Cough',
      if (lower.contains('throat')) 'Sore throat',
      if (lower.contains('pain')) 'Pain',
      if (lower.contains('breathlessness') ||
          lower.contains('shortness of breath'))
        'Breathlessness',
      if (lower.contains('headache')) 'Headache',
      if (lower.contains('vomiting')) 'Vomiting',
      if (lower.contains('diarrhea') || lower.contains('diarrhoea')) 'Diarrhea',
    ];
    return _dedupe(complaints);
  }

  List<String> _extractInvestigations(String lower) {
    final tests = <String>[
      if (lower.contains('cbc')) 'Complete blood count (CBC)',
      if (lower.contains('crp')) 'CRP',
      if (lower.contains('xray') || lower.contains('x-ray')) 'Chest X-ray',
      if (lower.contains('ecg')) 'ECG',
      if (lower.contains('lft')) 'LFT',
      if (lower.contains('rft') || lower.contains('renal function')) 'RFT',
      if (lower.contains('blood sugar') || lower.contains('glucose'))
        'Blood glucose',
      if (lower.contains('urine routine')) 'Urine routine',
      if (lower.contains('thyroid') || lower.contains('tsh')) 'Thyroid profile',
    ];
    return _dedupe(tests);
  }

  List<String> _extractVitals(String transcript) {
    final vitals = <String>[];
    final bp = RegExp(
            r'\b(?:bp|blood pressure)\s*(?:is|:)?\s*(\d{2,3}/\d{2,3})\b',
            caseSensitive: false)
        .firstMatch(transcript)
        ?.group(1);
    final pulse = RegExp(r'\b(?:pulse|pr)\s*(?:is|:)?\s*(\d{2,3})\b',
            caseSensitive: false)
        .firstMatch(transcript)
        ?.group(1);
    final temp = RegExp(
      r'\b(?:temp|temperature)\s*(?:is|:)?\s*(\d{2,3}(?:\.\d+)?)\s*(f|c)?\b',
      caseSensitive: false,
    ).firstMatch(transcript);
    final spo2 = RegExp(
            r'\b(?:spo2|spo2 saturation|oxygen saturation)\s*(?:is|:)?\s*(\d{2,3})\s*%?\b',
            caseSensitive: false)
        .firstMatch(transcript)
        ?.group(1);
    final rr = RegExp(r'\b(?:respiratory rate|rr)\s*(?:is|:)?\s*(\d{1,2})\b',
            caseSensitive: false)
        .firstMatch(transcript)
        ?.group(1);

    if (bp != null) vitals.add('BP: $bp mmHg');
    if (pulse != null) vitals.add('Pulse: $pulse/min');
    if (temp != null) {
      final unit = (temp.group(2) ?? 'F').toUpperCase();
      vitals.add('Temperature: ${temp.group(1)} $unit');
    }
    if (spo2 != null) vitals.add('SpO2: $spo2%');
    if (rr != null) vitals.add('Respiratory rate: $rr/min');

    return _dedupe(vitals);
  }

  List<String> _extractLabReports(String transcript) {
    final lower = transcript.toLowerCase();
    final labs = <String>[];

    if (lower.contains('wbc')) {
      final value =
          RegExp(r'\bwbc\s*(?:is|:)?\s*(\d{3,6})', caseSensitive: false)
              .firstMatch(transcript)
              ?.group(1);
      labs.add(value == null ? 'WBC reported' : 'WBC: $value');
    }
    if (lower.contains('hb') || lower.contains('hemoglobin')) {
      final value = RegExp(
              r'\b(?:hb|hemoglobin)\s*(?:is|:)?\s*(\d{1,2}(?:\.\d+)?)',
              caseSensitive: false)
          .firstMatch(transcript)
          ?.group(1);
      labs.add(
          value == null ? 'Hemoglobin reported' : 'Hemoglobin: $value g/dL');
    }
    if (lower.contains('platelet')) {
      final value = RegExp(r'\bplatelet[s]?\s*(?:is|:)?\s*(\d{3,7})',
              caseSensitive: false)
          .firstMatch(transcript)
          ?.group(1);
      labs.add(value == null ? 'Platelet count reported' : 'Platelets: $value');
    }
    if (lower.contains('crp')) {
      labs.add('CRP noted in lab context');
    }
    if (lower.contains('lab report') || lower.contains('reports show')) {
      labs.add('Lab report findings documented in transcript');
    }

    return _dedupe(labs);
  }

  List<String> _extractReferrals(String lower) {
    final referrals = <String>[
      if (lower.contains('refer to cardiology') ||
          lower.contains('cardiology consult'))
        'Cardiology consultation',
      if (lower.contains('refer to ent') || lower.contains('ent consult'))
        'ENT consultation',
      if (lower.contains('refer to surgery') ||
          lower.contains('surgical consult'))
        'General Surgery consultation',
      if (lower.contains('refer to ortho') ||
          lower.contains('orthopedic consult'))
        'Orthopedics consultation',
      if (lower.contains('refer to gyne') ||
          lower.contains('gynaec') ||
          lower.contains('obg'))
        'Obstetrics/Gynecology consultation',
      if (lower.contains('refer to medicine') ||
          lower.contains('physician consult'))
        'Internal Medicine consultation',
    ];
    return _dedupe(referrals);
  }

  List<String> _extractMedicalPlan(String lower) {
    final plans = <String>[
      if (lower.contains('start') ||
          lower.contains('prescribe') ||
          lower.contains('continue'))
        'Medical management initiated as per dictated treatment plan.',
      if (lower.contains('observe') || lower.contains('watchful waiting'))
        'Observation with close follow-up advised.',
      if (lower.contains('admit'))
        'Consider admission based on clinical progression.',
    ];
    return _dedupe(plans);
  }

  List<String> _extractSurgicalPlan(String lower) {
    final plans = <String>[
      if (lower.contains('surgery') || lower.contains('surgical option'))
        'Surgical option discussed.',
      if (lower.contains('laparoscopic') || lower.contains('laparoscopy'))
        'Laparoscopic intervention considered.',
      if (lower.contains('procedure planned') || lower.contains('operative'))
        'Operative planning mentioned.',
    ];
    return _dedupe(plans);
  }

  List<String> _extractAdvice(String lower) {
    final advice = <String>[
      if (lower.contains('hydration') || lower.contains('drink fluids'))
        'Maintain adequate hydration.',
      if (lower.contains('rest')) 'Take adequate rest.',
      if (lower.contains('follow up') || lower.contains('follow-up'))
        'Follow-up advised as per clinical response.',
      if (lower.contains('warning signs') || lower.contains('red flag'))
        'Counselled regarding red-flag warning signs.',
      if (lower.contains('diet')) 'Dietary advice provided.',
    ];
    return _dedupe(advice);
  }

  String _extractClinicalFindings(String lower) {
    final findings = <String>[];
    if (lower.contains('throat congestion')) {
      findings.add('Throat congestion present.');
    }
    if (lower.contains('chest clear')) {
      findings.add('Chest clear on auscultation.');
    }
    if (lower.contains('wheeze')) {
      findings.add('Wheeze noted.');
    }
    if (lower.contains('crepitations')) {
      findings.add('Crepitations noted.');
    }
    if (lower.contains('abdominal tenderness')) {
      findings.add('Abdominal tenderness present.');
    }
    if (findings.isEmpty) {
      return '';
    }
    return _dedupe(findings).join(' ');
  }

  String? _extractPatientName(String transcript) {
    final match = RegExp(
      r'\b(?:my name is|name is|patient name is|this is)\s+([a-z]+(?:\s+[a-z]+){0,3})',
      caseSensitive: false,
    ).firstMatch(transcript);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .map((e) => '${e[0].toUpperCase()}${e.substring(1).toLowerCase()}')
        .join(' ');
  }

  int? _extractPatientAge(String transcript) {
    final patterns = <RegExp>[
      RegExp(r'\b(?:i am|age is|aged?)\s+(\d{1,3})\b', caseSensitive: false),
      RegExp(r'\b(\d{1,3})\s*(?:years?|yrs?)\s*old\b', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(transcript);
      if (match == null) {
        continue;
      }
      final age = int.tryParse(match.group(1) ?? '');
      if (age != null && age > 0 && age < 130) {
        return age;
      }
    }
    return null;
  }

  String? _extractPatientGender(String lower) {
    if (lower.contains('female') || lower.contains('woman')) {
      return 'Female';
    }
    if (lower.contains('male') || lower.contains('man')) {
      return 'Male';
    }
    return null;
  }

  List<String> _dedupe(List<String> values) {
    return values
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
