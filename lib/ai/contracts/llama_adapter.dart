import '../../services/extraction_service/structured_extraction.dart';

abstract class LlamaAdapter {
  Future<StructuredExtraction> extract(String transcript);
}
