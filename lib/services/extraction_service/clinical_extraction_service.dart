import '../../ai/llama/llama_extractor.dart';

class ClinicalExtractionService {
  ClinicalExtractionService(this._extractor);

  final LlamaExtractor _extractor;

  Map<String, dynamic> extract(String transcript) => _extractor.extractStructuredData(transcript);
}
