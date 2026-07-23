import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart' as enc;
import '../data/database.dart';
import '../data/word_list.dart';
import '../models/user.dart';

// A short fixed piece of text used to check a derived key is correct
const String checkText = 'vault_ok';

// Holds everything register() needs to give back
// user and recoveryPhrase get shown once, vaultKey lets the app
// go straight into the vault right after registering
class RegisterResult {
  User user;
  String recoveryPhrase;
  String vaultKey;

  RegisterResult({
    required this.user,
    required this.recoveryPhrase,
    required this.vaultKey,
  });
}

class AuthService {
  final AppDatabase appDatabase;

  AuthService({required this.appDatabase});

  // Makes some random bytes, used for salts and for the vault key itself
  String generateRandomBase64(int byteCount) {
    Random random = Random.secure();
    List<int> bytes = List<int>.generate(byteCount, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  // Turns a password into an AES key using PBKDF2
  // The salt makes sure the same password does not always make the same key
  Future<String> deriveKey(String password, String saltBase64) async {
    List<int> saltBytes = base64Decode(saltBase64);

    Pbkdf2 pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );

    SecretKey secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: saltBytes,
    );

    List<int> keyBytes = await secretKey.extractBytes();
    return base64Encode(keyBytes);
  }

  // Encrypts one string with another key, used to wrap the vault key
  // and also used to make the check value
  String encryptWithKey(String plainText, String keyBase64) {
    enc.Key key = enc.Key.fromBase64(keyBase64);
    enc.IV iv = enc.IV.fromSecureRandom(16);
    enc.Encrypter encrypter = enc.Encrypter(enc.AES(key));

    enc.Encrypted encrypted = encrypter.encrypt(plainText, iv: iv);

    return iv.base64 + ':' + encrypted.base64;
  }

  // Decrypts a string made by encryptWithKey
  String decryptWithKey(String wrappedText, String keyBase64) {
    List<String> parts = wrappedText.split(':');
    enc.IV iv = enc.IV.fromBase64(parts[0]);
    enc.Encrypted encrypted = enc.Encrypted.fromBase64(parts[1]);

    enc.Key key = enc.Key.fromBase64(keyBase64);
    enc.Encrypter encrypter = enc.Encrypter(enc.AES(key));

    return encrypter.decrypt(encrypted, iv: iv);
  }

  // Picks 12 random words from the word list, with no repeats
  List<String> generateRecoveryPhraseWords() {
    List<String> wordsCopy = List<String>.from(wordList);
    wordsCopy.shuffle(Random.secure());
    return wordsCopy.take(12).toList();
  }

  // Creates a brand new user, called once during registration
  // Makes one vault key, then wraps it with both the password and a
  // freshly generated recovery phrase
  Future<RegisterResult> register({
    required String password,
  }) async {
    List<String> recoveryWords = generateRecoveryPhraseWords();
    String recoveryPhrase = recoveryWords.join(' ');

    String vaultKey = generateRandomBase64(32);

    String saltForPassword = generateRandomBase64(16);
    String saltForRecovery = generateRandomBase64(16);

    String keyFromPassword = await deriveKey(password, saltForPassword);
    String keyFromRecovery = await deriveKey(recoveryPhrase, saltForRecovery);

    String wrappedKeyFromPassword = encryptWithKey(vaultKey, keyFromPassword);
    String wrappedKeyFromRecovery = encryptWithKey(vaultKey, keyFromRecovery);

    String checkValue = encryptWithKey(checkText, vaultKey);

    User user = User(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      saltForPassword: saltForPassword,
      saltForRecovery: saltForRecovery,
      wrappedKeyFromPassword: wrappedKeyFromPassword,
      wrappedKeyFromRecovery: wrappedKeyFromRecovery,
      checkValue: checkValue,
    );

    await appDatabase.saveUser(user.toMap());

    return RegisterResult(
      user: user,
      recoveryPhrase: recoveryPhrase,
      vaultKey: vaultKey,
    );
  }

  // Loads the current user from SQLite, returns null if nobody registered yet
  Future<User?> getCurrentUser() async {
    Map<String, dynamic>? row = await appDatabase.getUser();

    if (row == null) {
      return null;
    }

    return User.fromMap(row);
  }

  // Tries to unlock the vault using the master password
  // Returns the vault key if the password was correct, otherwise null
  Future<String?> unlockWithPassword(User user, String password) async {
    String keyFromPassword = await deriveKey(password, user.saltForPassword);
    return unwrapAndCheck(user.wrappedKeyFromPassword, keyFromPassword, user.checkValue);
  }

  // Tries to unlock the vault using the recovery phrase
  // Returns the vault key if the recovery phrase was correct, otherwise null
  Future<String?> unlockWithRecovery(User user, String recoveryPhrase) async {
    String normalizedPhrase = normalizeRecoveryPhrase(recoveryPhrase);
    String keyFromRecovery = await deriveKey(normalizedPhrase, user.saltForRecovery);
    return unwrapAndCheck(user.wrappedKeyFromRecovery, keyFromRecovery, user.checkValue);
  }

  // Trims extra spaces and makes everything lowercase
  // Small typing differences should not break unlocking with the recovery phrase
  String normalizeRecoveryPhrase(String phrase) {
    List<String> words = phrase.trim().toLowerCase().split(RegExp(r'\s+'));
    return words.join(' ');
  }

  // Unwraps the vault key then checks it against the check value
  // A wrong password derives a wrong key, so decrypting either one fails
  String? unwrapAndCheck(String wrappedKey, String wrappingKey, String checkValue) {
    try {
      String vaultKey = decryptWithKey(wrappedKey, wrappingKey);
      String decryptedCheck = decryptWithKey(checkValue, vaultKey);

      if (decryptedCheck == checkText) {
        return vaultKey;
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
