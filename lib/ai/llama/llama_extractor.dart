import '../../ai/contracts/llama_adapter.dart';
import '../../services/extraction_service/structured_extraction.dart';

class LlamaExtractor implements LlamaAdapter {
  @override
  Future<StructuredExtraction> extract(String transcript) async {
    final lower = transcript.toLowerCase();
    final complaints = <String>[
      if (lower.contains('fever')) 'Fever',
      if (lower.contains('cough')) 'Cough',
      if (lower.contains('throat')) 'Sore throat',
      if (lower.contains('pain')) 'Pain',
    ];

    final investigations = <String>[
      if (lower.contains('cbc')) 'Complete blood count (CBC)',
      if (lower.contains('xray') || lower.contains('x-ray')) 'Chest X-ray',
      if (lower.contains('crp')) 'CRP',
    ];

    final warnings = <String>[];
    if (!lower.contains('blood pressure')) {
      warnings.add('Vitals incomplete: blood pressure not captured in transcript.');
    }

    return StructuredExtraction(
      chiefComplaints: complaints,
      history: transcript,
      examination: lower.contains('101f')
          ? 'Temperature 101°F, throat congestion.'
          : 'General physical examination captured.',
      investigations: investigations,
      warnings: warnings,
    );
  }
}
