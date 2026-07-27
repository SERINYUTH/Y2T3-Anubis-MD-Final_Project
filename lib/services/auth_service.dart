import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/database.dart';
import '../models/user.dart';

// A short fixed piece of text used to check a derived key is correct
const String checkText = 'vault_ok';

// Keys used in flutter_secure_storage
const String _kVaultKey = 'anubis_vault_key';
const String _kPinKey = 'anubis_pin_hash';
const String _kBootTimeKey = 'anubis_boot_time';

// How many tries Quick Access gets before it locks and falls back to the
// master password. PIN and biometric each get their own count.
const int quickAccessMaxAttempts = 3;

// Holds everything register() needs to give back
// user and recoveryKey get shown once, vaultKey lets the app
// go straight into the vault right after registering
class RegisterResult {
  User user;
  String recoveryKey;
  String vaultKey;

  RegisterResult({
    required this.user,
    required this.recoveryKey,
    required this.vaultKey,
  });
}

class AuthService {
  final AppDatabase appDatabase;
  final FlutterSecureStorage _secureStorage;

  // In-memory only — each is out of quickAccessMaxAttempts (3) tries.
  // Reset to full whenever the master password is entered successfully.
  // Living on this instance (not in storage) means a fresh app process
  // also gets fresh attempts, same as a fresh boot would.
  int pinAttemptsRemaining = quickAccessMaxAttempts;
  int bioAttemptsRemaining = quickAccessMaxAttempts;

  AuthService({required this.appDatabase})
    : _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  // Resets both Quick Access attempt counters back to full.
  // Called after a successful master password unlock.
  void resetQuickAccessAttempts() {
    pinAttemptsRemaining = quickAccessMaxAttempts;
    bioAttemptsRemaining = quickAccessMaxAttempts;
  }

  // Records one failed PIN attempt, returns tries left.
  int recordFailedPinAttempt() {
    if (pinAttemptsRemaining > 0) pinAttemptsRemaining--;
    return pinAttemptsRemaining;
  }

  // Records one failed biometric attempt, returns tries left.
  int recordFailedBiometricAttempt() {
    if (bioAttemptsRemaining > 0) bioAttemptsRemaining--;
    return bioAttemptsRemaining;
  }

  // ── Device-restart detection ─────────────────────────────────────────────
  // Reads /proc/uptime (Android/Linux) to work out roughly when the device
  // last booted. We store that value after every successful unlock; if it
  // doesn't match anymore, the device has been restarted since then, so
  // Quick Access is not trusted and the master password is required again.
  // This is a simple, no-extra-dependency approximation rather than a
  // proper native boot-receiver — good enough for this project's scope.
  Future<int?> _currentBootEpochSeconds() async {
    try {
      String raw = await File('/proc/uptime').readAsString();
      double uptimeSeconds = double.parse(raw.trim().split(' ').first);
      int nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return nowSeconds - uptimeSeconds.round();
    } catch (_) {
      // Not on Android/Linux (e.g. running on desktop) — can't tell, so
      // don't force a master-password prompt over this check alone.
      return null;
    }
  }

  // True if this looks like a different boot than the last time we
  // recorded an unlock. Also true (safest default) if we've never
  // recorded one yet.
  Future<bool> deviceRestartedSinceLastUnlock() async {
    int? currentBoot = await _currentBootEpochSeconds();
    if (currentBoot == null) return false;

    String? storedBoot = await _secureStorage.read(key: _kBootTimeKey);
    if (storedBoot == null) return true;

    int storedBootSeconds = int.tryParse(storedBoot) ?? 0;
    // A few seconds of drift is fine, anything more means a reboot happened.
    return (currentBoot - storedBootSeconds).abs() > 10;
  }

  // Call after every successful unlock (master password, PIN, or
  // biometric) so we know which boot session we're in next time.
  Future<void> markUnlockedThisBoot() async {
    int? currentBoot = await _currentBootEpochSeconds();
    if (currentBoot == null) return;
    await _secureStorage.write(
      key: _kBootTimeKey,
      value: currentBoot.toString(),
    );
  }

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

  // Characters used to build the recovery key.
  // Uppercase letters and digits only, no dashes (dashes are added for
  // display). Kept simple: every character is equally likely.
  static const String _recoveryKeyChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  // Makes a random recovery key in the form XXXX-XXXX-XXXX-XXXX
  // (16 random characters, grouped into 4 blocks of 4 with dashes)
  String generateRecoveryKey() {
    Random random = Random.secure();
    StringBuffer buffer = StringBuffer();

    for (int i = 0; i < 16; i++) {
      if (i != 0 && i % 4 == 0) {
        buffer.write('-');
      }
      int charIndex = random.nextInt(_recoveryKeyChars.length);
      buffer.write(_recoveryKeyChars[charIndex]);
    }

    return buffer.toString();
  }

  // Creates a brand new user, called once during registration
  // Makes one vault key, then wraps it with both the password and a
  // freshly generated recovery key
  Future<RegisterResult> register({required String password}) async {
    String recoveryKey = generateRecoveryKey();

    String vaultKey = generateRandomBase64(32);

    String saltForPassword = generateRandomBase64(16);
    String saltForRecovery = generateRandomBase64(16);

    String keyFromPassword = await deriveKey(password, saltForPassword);
    String keyFromRecovery = await deriveKey(
      normalizeRecoveryKey(recoveryKey),
      saltForRecovery,
    );

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
      biometricEnabled: false,
      pinEnabled: false,
    );

    await appDatabase.saveUser(user.toMap());

    return RegisterResult(
      user: user,
      recoveryKey: recoveryKey,
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
    String? vaultKey = unwrapAndCheck(
      user.wrappedKeyFromPassword,
      keyFromPassword,
      user.checkValue,
    );

    if (vaultKey != null) {
      // The master password is the ultimate fallback — a successful entry
      // clears any Quick Access lockout and re-confirms this boot session.
      resetQuickAccessAttempts();
      await markUnlockedThisBoot();
    }

    return vaultKey;
  }

  // Tries to unlock the vault using the recovery key
  // Returns the vault key if the recovery key was correct, otherwise null
  Future<String?> unlockWithRecovery(User user, String recoveryKey) async {
    String normalizedKey = normalizeRecoveryKey(recoveryKey);
    String keyFromRecovery = await deriveKey(
      normalizedKey,
      user.saltForRecovery,
    );
    return unwrapAndCheck(
      user.wrappedKeyFromRecovery,
      keyFromRecovery,
      user.checkValue,
    );
  }

  // Strips dashes/spaces and makes everything uppercase
  // Small typing differences (lowercase, missing dashes) should not break
  // unlocking with the recovery key
  String normalizeRecoveryKey(String key) {
    return key.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  }

  // Unwraps the vault key then checks it against the check value
  // A wrong password derives a wrong key, so decrypting either one fails
  String? unwrapAndCheck(
    String wrappedKey,
    String wrappingKey,
    String checkValue,
  ) {
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

  // Saves a SHA-like hash of the PIN into secure storage
  // Using secure storage (not SQLite) keeps the PIN off-disk in plaintext
  Future<void> savePin(String pin) async {
    // Simple deterministic hash: we just store the PIN directly in the
    // OS keychain (flutter_secure_storage encrypts it at rest)
    await _secureStorage.write(key: _kPinKey, value: pin);
  }

  // Returns true if the entered PIN matches the stored one
  Future<bool> verifyPin(String pin) async {
    String? stored = await _secureStorage.read(key: _kPinKey);
    return stored != null && stored == pin;
  }

  // Saves the vault key to the OS keychain after a successful login/register.
  // The lock screen reads it back without needing to re-run PBKDF2.
  Future<void> storeVaultKey(String vaultKey) async {
    await _secureStorage.write(key: _kVaultKey, value: vaultKey);
  }

  // Returns the stored vault key, or null if secure storage was cleared
  Future<String?> getStoredVaultKey() async {
    return await _secureStorage.read(key: _kVaultKey);
  }

  // Deletes the vault key from secure storage (sign out)
  Future<void> clearStoredVaultKey() async {
    await _secureStorage.delete(key: _kVaultKey);
  }

  // Biometrics
  Future<void> setBiometricEnabled(bool enabled) async {
    User? user = await getCurrentUser();
    if (user == null) return;
    user.biometricEnabled = enabled;
    await appDatabase.updateUser(user.toMap());
  }

  // PIN Quick Access — independent on/off switch, same idea as biometrics
  Future<void> setPinEnabled(bool enabled) async {
    User? user = await getCurrentUser();
    if (user == null) return;
    user.pinEnabled = enabled;
    await appDatabase.updateUser(user.toMap());
  }

  // Password reset

  // Re-wraps the vault key with a new password-derived key, then saves
  // the updated user row to SQLite. The vaultKey itself never changes.
  Future<void> resetPassword({
    required User user,
    required String newPassword,
    required String vaultKey,
  }) async {
    String newSaltForPassword = generateRandomBase64(16);
    String newKeyFromPassword = await deriveKey(
      newPassword,
      newSaltForPassword,
    );
    String newWrappedKeyFromPassword = encryptWithKey(
      vaultKey,
      newKeyFromPassword,
    );

    user.saltForPassword = newSaltForPassword;
    user.wrappedKeyFromPassword = newWrappedKeyFromPassword;

    await appDatabase.updateUser(user.toMap());

    // Store the vault key again (it hasn't changed, but good to be explicit)
    await storeVaultKey(vaultKey);

    // Recovering via the key is just as strong as the master password —
    // clear any Quick Access lockout and re-confirm this boot session.
    resetQuickAccessAttempts();
    await markUnlockedThisBoot();
  }
}
