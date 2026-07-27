// Holds everything needed to unlock the vault on this device
// vaultKey itself is never stored, only wrapped (encrypted) copies of it
class User {
  String id;

  // Random bytes used so the same password does not always make the same key
  String saltForPassword;
  String saltForRecovery;

  // The vault key encrypted with a key derived from the master password
  String wrappedKeyFromPassword;
  // The vault key encrypted with a key derived from the recovery key
  String wrappedKeyFromRecovery;

  // A known short text encrypted with the vault key
  // Used to check a derived key is correct before trusting it
  String checkValue;

  // Whether biometric unlock is enabled on this device
  bool biometricEnabled;

  // Whether PIN unlock (Quick Access) is enabled on this device.
  // Separate from biometricEnabled — either, both, or neither can be on.
  // Master password is always the fallback if neither is enabled.
  bool pinEnabled;

  User({
    required this.id,
    required this.saltForPassword,
    required this.saltForRecovery,
    required this.wrappedKeyFromPassword,
    required this.wrappedKeyFromRecovery,
    required this.checkValue,
    this.biometricEnabled = false,
    this.pinEnabled = false,
  });

  // Turns this User into a Map so it can be saved as one row in SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saltForPassword': saltForPassword,
      'saltForRecovery': saltForRecovery,
      'wrappedKeyFromPassword': wrappedKeyFromPassword,
      'wrappedKeyFromRecovery': wrappedKeyFromRecovery,
      'checkValue': checkValue,
      'biometricEnabled': biometricEnabled ? 1 : 0,
      'pinEnabled': pinEnabled ? 1 : 0,
    };
  }

  // Turns a row read from SQLite back into a User object
  static User fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      saltForPassword: map['saltForPassword'],
      saltForRecovery: map['saltForRecovery'],
      wrappedKeyFromPassword: map['wrappedKeyFromPassword'],
      wrappedKeyFromRecovery: map['wrappedKeyFromRecovery'],
      checkValue: map['checkValue'],
      biometricEnabled: (map['biometricEnabled'] ?? 0) == 1,
      pinEnabled: (map['pinEnabled'] ?? 0) == 1,
    );
  }

  // True if any Quick Access method is on. When false, the master
  // password is the only way into the vault.
  bool get hasQuickAccess => biometricEnabled || pinEnabled;
}
