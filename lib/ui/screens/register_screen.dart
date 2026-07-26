import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/encryption_service.dart';
import '../../repositories/credential_repository.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import '../widgets/app_text_field.dart';
import 'recover_phrase_screen.dart';

// Lets the user set a master password and creates the account
// No email field, since the app is fully offline there is nothing to verify it against
class RegisterScreen extends StatefulWidget {
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const RegisterScreen({
    super.key,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  TextEditingController passwordController = TextEditingController();

  bool passwordHidden = true;
  bool isSaving = false;
  String errorMessage = '';

  // Called when Continue is tapped
  Future<void> continuePressed() async {
    String password = passwordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a master password.';
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        errorMessage = 'Password must be at least 8 characters.';
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = '';
    });

    RegisterResult result = await widget.authService.register(password: password);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecoverPhraseScreen(
            user: result.user,
            recoveryPhrase: result.recoveryPhrase,
            vaultKey: result.vaultKey,
            authService: widget.authService,
            credentialRepository: widget.credentialRepository,
            encryptionService: widget.encryptionService
          ),
        ),
      );
    }

    setState(() {
      isSaving = false;
    });
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

              const SizedBox(height: 24),

              AppTextField(
                label: 'Master Password',
                controller: passwordController,
                hintText: 'Enter a strong password',
                obscureText: passwordHidden,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      passwordHidden = !passwordHidden;
                    });
                  },
                  icon: Icon(
                    passwordHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Shared.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "This is the only password you'll need to remember.",
                style: TextStyle(color: Shared.textSecondary, fontSize: 12),
              ),

              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Shared.error),
                ),
              ],

              const SizedBox(height: 32),

              isSaving
                  ? const Center(
                      child: CircularProgressIndicator(color: Shared.gold),
                    )
                  : PrimaryButton(
                      label: 'Continue',
                      onPressed: continuePressed,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
