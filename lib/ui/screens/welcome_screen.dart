import 'package:flutter/material.dart';
import '../../repositories/credential_repository.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import 'register_screen.dart';

// First screen shown, this is just a shell for now
// no real auth logic yet
class WelcomeScreen extends StatelessWidget {
  final CredentialRepository credentialRepository;
  final encryptionService;

  const WelcomeScreen({
    super.key,
    required this.credentialRepository,
    required this.encryptionService,
  });

  void openRegisterScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterScreen(
          credentialRepository: credentialRepository,
          encryptionService: encryptionService,
        ),
      ),
    );
  }

  // Log In leads to the same shell flow for now, login is not built yet
  void openLoginScreen(BuildContext context) {
    openRegisterScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Shared.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 3),

              const Text(
                'Anubis',
                style: TextStyle(
                  color: Shared.gold,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Your credentials, locked and local.',
                style: TextStyle(color: Shared.textSecondary, fontSize: 14),
              ),

              const Spacer(flex: 5),

              PrimaryButton(
                label: 'Create Account',
                onPressed: () {
                  openRegisterScreen(context);
                },
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: Shared.buttonHeight,
                child: OutlinedButton(
                  onPressed: () {
                    openLoginScreen(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Shared.gold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
                    ),
                  ),
                  child: const Text(
                    'Log In',
                    style: TextStyle(color: Shared.gold, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
