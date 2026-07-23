import 'package:encrypt/encrypt.dart';

// Handles AES encrypt and decrypt for credential data
// aesKey is a base64 string, it was derived earlier from the master password
class EncryptionService {
  // Encrypts a plain text string, returns iv and cipher text joined by a colon
  // The iv must be saved along with the cipher text or it cannot be decrypted later
  Future<String> encrypt(String plainText, String aesKey) async {
    Key key = Key.fromBase64(aesKey);
    IV iv = IV.fromSecureRandom(16);
    Encrypter encrypter = Encrypter(AES(key));

    Encrypted encrypted = encrypter.encrypt(plainText, iv: iv);

    String result = iv.base64 + ':' + encrypted.base64;
    return result;
  }

  // Splits the iv back out from the cipher text, then decrypts it
  Future<String> decrypt(String encryptedText, String aesKey) async {
    List<String> parts = encryptedText.split(':');
    String ivBase64 = parts[0];
    String cipherBase64 = parts[1];

    Key key = Key.fromBase64(aesKey);
    IV iv = IV.fromBase64(ivBase64);
    Encrypter encrypter = Encrypter(AES(key));

    Encrypted encrypted = Encrypted.fromBase64(cipherBase64);
    String plainText = encrypter.decrypt(encrypted, iv: iv);

    return plainText;
  }
}
