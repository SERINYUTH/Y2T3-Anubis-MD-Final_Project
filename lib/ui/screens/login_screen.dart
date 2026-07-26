import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import '../widgets/app_text_field.dart';
import 'vault_screen.dart';
import 'forgot_passwd_screen.dart';

// Login screen for users who already have an account on this device but
// are coming in fresh (e.g. after app reinstall or clearing secure storage).
// Uses the master password path: PBKDF2 → unwrap vault key → enter vault.
class LoginScreen extends StatefulWidget {
  final User user;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const LoginScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final passwordController = TextEditingController();

  bool passwordHidden = true;
  bool isLoading = false;
  String errorMessage = '';

  Future<void> login() async {
    String password = passwordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your master password.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    String? vaultKey = await widget.authService.unlockWithPassword(
      widget.user,
      password,
    );

    if (!mounted) return;

    if (vaultKey == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Incorrect password. Please try again.';
      });
      return;
    }

    // Password correct — clear the stack and open the vault
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => VaultScreen(
          credentialRepository: widget.credentialRepository,
          encryptionService: widget.encryptionService,
          aesKey: vaultKey,
          authService: widget.authService,
          user: widget.user,
        ),
      ),
      (route) => false,
    );
  }

  void openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          user: widget.user,
          authService: widget.authService,
          credentialRepository: widget.credentialRepository,
          encryptionService: widget.encryptionService,
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              const Text(
                'Welcome back',
                style: TextStyle(
                  color: Shared.gold,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Enter your master password to open the vault.',
                style: TextStyle(color: Shared.textSecondary, fontSize: 14),
              ),

              const Spacer(flex: 2),

              AppTextField(
                label: 'Master Password',
                controller: passwordController,
                hintText: 'Enter your master password',
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

              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Shared.error, fontSize: 13),
                ),
              ],

              const SizedBox(height: 24),

              isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Shared.gold),
                    )
                  : PrimaryButton(label: 'Unlock Vault', onPressed: login),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: openForgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: Shared.gold, fontSize: 14),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
