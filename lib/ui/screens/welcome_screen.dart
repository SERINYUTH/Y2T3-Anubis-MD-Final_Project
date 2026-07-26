import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/encryption_service.dart';
import '../../repositories/credential_repository.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import 'register_screen.dart';
import 'login_screen.dart';
import '../../models/user.dart';

// First screen the user sees when no account exists yet
// No back arrow here, this is the very first screen
class WelcomeScreen extends StatelessWidget {
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  // Null when no account has been registered yet.
  // Non-null means an account exists but the user signed out — Login is valid.
  final User? existingUser;

  const WelcomeScreen({
    super.key,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
    this.existingUser
  });

  // Called when Log In is tapped, login screen is not built yet
  void _openLoginScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          user: existingUser!,
          authService: authService,
          credentialRepository: credentialRepository,
          encryptionService: encryptionService,
        ),
      ),
    );
  }

  void _openRegisterScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterScreen(
          authService: authService,
          credentialRepository: credentialRepository,
          encryptionService: encryptionService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If an account already exists but the user signed out, only show Log In
    bool hasAccount = existingUser != null;

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
          
              if (!hasAccount) ...[
                PrimaryButton(
                  label: 'Create Account',
                  onPressed: () {
                    _openRegisterScreen(context);
                  },
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: Shared.buttonHeight,
                child: OutlinedButton(
                  onPressed: hasAccount 
                    ? () => _openLoginScreen(context)
                    : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: hasAccount ? Shared.gold : Shared.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
                    ),
                  ),
                  child: Text(
                    'Log In',
                    style: TextStyle(
                      color: hasAccount ? Shared.gold : Shared.textSecondary, 
                      fontWeight: FontWeight.bold),
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
