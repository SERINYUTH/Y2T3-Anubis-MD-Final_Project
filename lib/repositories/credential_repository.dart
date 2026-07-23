import '../data/database.dart';
import '../models/credential.dart';
import '../models/category.dart';

class CredentialRepository {
  // Talks to the local SQLite database
  final AppDatabase appDatabase;

  CredentialRepository({
    required this.appDatabase,
  });

  // Reads every credential from SQLite
  Future<List<Credential>> getAllCredentials() async {
    List<Map<String, dynamic>> rows = await appDatabase.getAllRows();

    List<Credential> credentials = [];
    for (var row in rows) {
      Credential credential = Credential.fromMap(row['id'], row);
      credentials.add(credential);
    }

    return credentials;
  }

  // Reads only the credentials that belong to one category
  // Used when the user taps a category filter chip on the Vault Screen
  Future<List<Credential>> getCredentialsByCategory(
    CredentialCategory category,
  ) async {
    List<Credential> allCredentials = await getAllCredentials();

    List<Credential> filtered = [];
    for (var credential in allCredentials) {
      if (credential.category == category) {
        filtered.add(credential);
      }
    }

    return filtered;
  }

  // Saves a credential to SQLite
  // Used for both adding a new one and editing an existing one
  Future<void> saveCredential(Credential credential) async {
    Map<String, dynamic> row = credential.toMap();
    row['id'] = credential.id;
    await appDatabase.insertCredential(row);
  }

  // Deletes a credential by its id
  Future<void> deleteCredential(String credentialId) async {
    await appDatabase.deleteRow(credentialId);
  }
}
