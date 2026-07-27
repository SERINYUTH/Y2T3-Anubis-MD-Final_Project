import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../../services/auth_service.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import 'quick_access_setup_screen.dart';

// Shows the recovery key once, right after registering
// No back arrow here on purpose, the account is already created by
// this point so going back to Register would not make sense
class RecoveryKeyScreen extends StatelessWidget {
  final User user;
  final String recoveryKey;
  final String vaultKey;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const RecoveryKeyScreen({
    super.key,
    required this.user,
    required this.recoveryKey,
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

  void _copyKey(BuildContext context) {
    Clipboard.setData(ClipboardData(text: recoveryKey));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recovery key copied')),
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
                'Save Your Recovery Key',
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

              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Shared.surface,
                  borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
                  border: Border.all(color: Shared.border),
                ),
                child: Column(
                  children: [
                    Text(
                      recoveryKey,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Shared.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => _copyKey(context),
                      icon: const Icon(Icons.copy, color: Shared.gold, size: 18),
                      label: const Text(
                        'Copy to clipboard',
                        style: TextStyle(color: Shared.gold),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

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
}
