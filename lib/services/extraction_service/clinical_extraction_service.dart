import '../../ai/contracts/llama_adapter.dart';
import 'structured_extraction.dart';
import 'structured_extraction_validator.dart';

class ClinicalExtractionService {
  ClinicalExtractionService(this._adapter, this._validator);

  final LlamaAdapter _adapter;
  final StructuredExtractionValidator _validator;

  Future<StructuredExtraction> extract(String transcript) async {
    final raw = await _adapter.extract(transcript);
    return _validator.validate(raw);
  }
}
