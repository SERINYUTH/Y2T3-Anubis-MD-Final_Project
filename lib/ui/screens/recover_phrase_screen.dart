import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../../services/auth_service.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import 'quick_access_setup_screen.dart';

// Shows the 12 word recovery phrase once, right after registering
// No back arrow here on purpose, the account is already created by
// this point so going back to Register would not make sense
class RecoverPhraseScreen extends StatelessWidget {
  final User user;
  final String recoveryPhrase;
  final String vaultKey;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const RecoverPhraseScreen({
    super.key,
    required this.user,
    required this.recoveryPhrase,
    required this.vaultKey,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
  });

  void _openQuickAccessSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickAccessSetupScreen(
          user: user,
          vaultKey: vaultKey,
          authService: authService,
          credentialRepository: credentialRepository,
          encryptionService: encryptionService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> words = recoveryPhrase.split(' ');

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

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Shared.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
                ),
                child: const Text(
                  "Write this down. It's the only way to recover your vault if you forget your password.",
                  style: TextStyle(color: Shared.error, fontSize: 13),
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    return buildWordCard(index + 1, words[index]);
                  },
                ),
              ),

              const SizedBox(height: 20),

              PrimaryButton(
                label: "I've Saved It - Continue",
                onPressed: () => _openQuickAccessSetup(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // One numbered word card, e.g. 1  apple
  Widget buildWordCard(int number, String word) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Shared.surface,
        borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
        border: Border.all(color: Shared.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$number',
            style: const TextStyle(color: Shared.gold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            word,
            style: const TextStyle(color: Shared.textPrimary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
