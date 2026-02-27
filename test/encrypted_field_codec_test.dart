import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/core/security/encrypted_field_codec.dart';

void main() {
  test('encrypt/decrypt roundtrip works', () {
    final codec = EncryptedFieldCodec('secret');
    const text = 'clinical note';

    final encrypted = codec.encrypt(text);
    final decrypted = codec.decrypt(encrypted);

    expect(decrypted, text);
  });
}
