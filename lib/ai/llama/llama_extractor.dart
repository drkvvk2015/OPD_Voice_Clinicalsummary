class LlamaExtractor {
  Map<String, dynamic> extractStructuredData(String transcript) {
    final lower = transcript.toLowerCase();

    return {
      'chiefComplaints': [
        if (lower.contains('fever')) 'Fever',
        if (lower.contains('cough')) 'Cough',
        if (lower.contains('sore throat')) 'Sore throat',
      ],
      'history': transcript,
      'examination':
          lower.contains('101f') ? 'Temperature 101°F, throat congestion.' : 'General exam noted.',
      'investigations': [
        if (lower.contains('cbc')) 'Complete blood count (CBC)',
      ],
    };
  }
}
