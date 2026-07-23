import 'package:flutter/material.dart';
import '../../repositories/credential_repository.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import 'vault_screen.dart';

// This is just a shell for now, no real recovery phrase logic yet
// Tapping the button leads straight through to the vault
class RecoverPhraseScreen extends StatelessWidget {
  final String vaultKey;
  final CredentialRepository credentialRepository;
  final encryptionService;

  const RecoverPhraseScreen({
    super.key,
    required this.vaultKey,
    required this.credentialRepository,
    required this.encryptionService,
  });

  void openVaultScreen(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => VaultScreen(
          credentialRepository: credentialRepository,
          encryptionService: encryptionService,
          aesKey: vaultKey,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Shared.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Save Your Recovery Phrase',
                style: TextStyle(
                  color: Shared.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Recovery phrase screen shell, no logic yet',
                style: TextStyle(color: Shared.textSecondary, fontSize: 13),
              ),

              const Spacer(),

              PrimaryButton(
                label: "I've Saved It",
                onPressed: () {
                  openVaultScreen(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
