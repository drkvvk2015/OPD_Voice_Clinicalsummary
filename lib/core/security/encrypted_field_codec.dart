import 'dart:convert';

class EncryptedFieldCodec {
  EncryptedFieldCodec(this._secret);

  final String _secret;

  String encrypt(String plainText) {
    final plain = utf8.encode(plainText);
    final key = utf8.encode(_secret);
    final encoded = List<int>.generate(
      plain.length,
      (index) => plain[index] ^ key[index % key.length],
      growable: false,
    );
    return base64Encode(encoded);
  }

  String decrypt(String cipherText) {
    final cipher = base64Decode(cipherText);
    final key = utf8.encode(_secret);
    final decoded = List<int>.generate(
      cipher.length,
      (index) => cipher[index] ^ key[index % key.length],
      growable: false,
    );
    return utf8.decode(decoded);
  }
}
