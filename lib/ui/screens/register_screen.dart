import 'package:flutter/material.dart';
import '../../repositories/credential_repository.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import 'recover_phrase_screen.dart';

// This is just a shell for now, no real registration logic yet
// Tapping Continue leads straight through to the Recovery Phrase shell
class RegisterScreen extends StatelessWidget {
  final CredentialRepository credentialRepository;
  final encryptionService;

  const RegisterScreen({
    super.key,
    required this.credentialRepository,
    required this.encryptionService,
  });

  void openRecoverPhraseScreen(BuildContext context) {
    // Placeholder key, register() is not called yet
    String placeholderVaultKey = 'RQhaA/5ApSn3+jSTi3Hz2PyXv2/isJHcR6ppa+hkz5U=';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecoverPhraseScreen(
          vaultKey: placeholderVaultKey,
          credentialRepository: credentialRepository,
          encryptionService: encryptionService,
        ),
      ),
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
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back, color: Shared.textPrimary),
              ),

              const SizedBox(height: 12),

              const Text(
                'Create Your Vault',
                style: TextStyle(
                  color: Shared.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Register screen shell, no logic yet',
                style: TextStyle(color: Shared.textSecondary, fontSize: 13),
              ),

              const Spacer(),

              PrimaryButton(
                label: 'Continue',
                onPressed: () {
                  openRecoverPhraseScreen(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
