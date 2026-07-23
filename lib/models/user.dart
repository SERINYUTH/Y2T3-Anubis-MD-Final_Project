// Holds everything needed to unlock the vault on this device
class User {
  String id;

  // Random bytes used so the same password does not always make the same key
  String saltForPassword;
  String saltForRecovery;

  // The vault key encrypted with a key derived from the master password
  String wrappedKeyFromPassword;
  // The vault key encrypted with a key derived from the recovery phrase
  String wrappedKeyFromRecovery;

  // A known short text encrypted with the vault key
  // Used to check a derived key is correct before trusting it
  String checkValue;

  User({
    required this.id,
    required this.saltForPassword,
    required this.saltForRecovery,
    required this.wrappedKeyFromPassword,
    required this.wrappedKeyFromRecovery,
    required this.checkValue,
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
    );
  }
}
