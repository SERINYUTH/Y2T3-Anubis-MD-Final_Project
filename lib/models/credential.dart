import 'dart:convert';
import 'category.dart';

// This class holds the actual sensitive information for one credent
// This class is only ever kept in memory for a short time
class CredentialData {
  String title;
  String username;
  String password;
  String url;

  CredentialData({
    required this.title,
    required this.username,
    required this.password,
    required this.url,
  });

  // Convert into JSON format gets encrypted with AES before saved anywhere.
  String toJsonString() {
    Map<String, String> data = {
      'title': title,
      'username': username,
      'password': password,
      'url': url,
    };
    String jsonString = jsonEncode(data);
    return jsonString;
  }

  // Convert a plain text JSON string and turns it back into a CredentialData object.
  static CredentialData fromJsonString(String jsonString) {
    Map<String, dynamic> data = jsonDecode(jsonString);
    CredentialData result = CredentialData(
      title: data['title'],
      username: data['username'],
      password: data['password'],
      url: data['url'],
    );
    return result;
  }
}

// This class represents one credential exactly as it is stored (local SQLite/Firebase Realtime Database)
class Credential {
  String id;
  String encryptedData;           // AES-encrypted version of a CredentialData
  CredentialCategory category;    // stored as plain text
  DateTime updatedAt;

  Credential({
    required this.id,
    required this.encryptedData,
    required this.category,
    required this.updatedAt,
  });

  // Convert this Credential into a simple Map, so it can be saved as one node under "credentials" in Firebase Realtime Database.
  // Note: we do not include "id" here, because in Realtime Database the node's key (its position in the tree) already acts as the ID.
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'encryptedData': encryptedData,
      'category': category.name,
      'updatedAt': updatedAt.toIso8601String(),
    };
    return map;
  }

  // Convert one node read from Realtime Database and turns it back into a Credential object.
  static Credential fromMap(
    String nodeKey,
    Map<String, dynamic> map,
  ) {
    Credential result = Credential(
      id: nodeKey,
      encryptedData: map['encryptedData'],
      category: CredentialCategory.values.byName(map['category']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
    return result;
  }
}