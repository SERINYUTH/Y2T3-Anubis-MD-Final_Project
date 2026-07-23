import 'package:flutter/material.dart';
import 'data/database.dart';
import 'repositories/credential_repository.dart';
import 'services/encryption_service.dart';
import 'ui/screens/welcome_screen.dart';

// For now the app always starts at the Welcome screen
// Auth is cleared out for this checkpoint, only the vault is fully working
// Welcome, Register, and Recovery Phrase are shells that lead straight to it
void main() {
  runApp(const AnubisApp());
}

class AnubisApp extends StatelessWidget {
  const AnubisApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppDatabase appDatabase = AppDatabase();
    CredentialRepository credentialRepository = CredentialRepository(
      appDatabase: appDatabase,
    );
    EncryptionService encryptionService = EncryptionService();

    return MaterialApp(
      home: WelcomeScreen(
        credentialRepository: credentialRepository,
        encryptionService: encryptionService,
      ),
    );
  }
}
