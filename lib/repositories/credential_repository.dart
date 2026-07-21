import 'dart:convert';
import 'dart:io';
import '../models/credential.dart';
import '../models/category.dart';

class CredentialRepository {
  // Passed in from outside this class
  // It knows how to read/write Firebase Realtime Database
  final firebaseService;

  // Holds a copy of all credentials locally to show data while offline
  final File localCacheFile;

  CredentialRepository({
    required this.firebaseService,
    required this.localCacheFile,
  });

  // Checks connection before every write (add, edit, delete)
  Future<bool> isOnline() async {
    bool connected = await firebaseService.checkConnection();
    return connected;
  }

  // Read & Turns local file into a Map
  // If not exist yet (ex: on first app launch), returns an empty Map instead of crashing
  Future<Map<String, dynamic>> readCacheFile() async {
    bool fileExists = await localCacheFile.exists();

    if (fileExists == false) {
      return {};
    }

    String fileContents = await localCacheFile.readAsString();

    if (fileContents.isEmpty) {
      return {};
    }

    Map<String, dynamic> data = jsonDecode(fileContents);
    return data;
  }

  // Writes a Map to the local cache file, replacing all
  // Every changes should go through this function, so the file is always written the same way
  Future<void> writeCacheFile(Map<String, dynamic> data) async {
    String jsonString = jsonEncode(data);
    await localCacheFile.writeAsString(jsonString);
  }

  // Reads every credential from the local JSON cache file
  Future<List<Credential>> getAllCredentials() async {
    Map<String, dynamic> data = await readCacheFile();

    List<Credential> credentials = [];
    data.forEach((id, map) {
      Credential credential = Credential.fromMap(id, map);
      credentials.add(credential);
    });

    return credentials;
  }

  // Reads only the credentials that belong to one category.
  // Used when the user taps a category filter chip on the Vault Screen.
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

  // Adds a new credential (online only)
  // true if it succeeded, false if it no internet connection
  Future<bool> addCredential(Credential credential) async {
    bool online = await isOnline();

    if (online == false) {
      // Cannot add a credential while offline
      return false;
    }

    // Save to Firebase Realtime Database
    await firebaseService.saveCredential(credential.id, credential.toMap());

    // Update the local JSON cache file to match
    Map<String, dynamic> data = await readCacheFile();
    data[credential.id] = credential.toMap();
    await writeCacheFile(data);

    return true;
  }

  // Updates an existing credential (when online)
  // Returns true if it succeeded, false if no internet connection
  Future<bool> updateCredential(Credential credential) async {
    bool online = await isOnline();

    if (online == false) {
      // Cannot edit a credential while offline
      return false;
    }

    await firebaseService.saveCredential(credential.id, credential.toMap());

    Map<String, dynamic> data = await readCacheFile();
    data[credential.id] = credential.toMap();
    await writeCacheFile(data);

    return true;
  }

  // Deletes a credential by its id (when online)
  // Returns true if it succeeded, false if no internet connection
  Future<bool> deleteCredential(String credentialId) async {
    bool online = await isOnline();

    if (online == false) {
      // Cannot delete a credential while offline
      return false;
    }

    await firebaseService.deleteCredential(credentialId);

    Map<String, dynamic> data = await readCacheFile();
    data.remove(credentialId);
    await writeCacheFile(data);

    return true;
  }

  // Downloads all credential from DB and replaces the local cache
  Future<void> refreshCacheFromFirebase() async {
    Map<String, dynamic> allNodes = await firebaseService
        .getAllCredentialNodes();
    await writeCacheFile(allNodes);
  }
}
