import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import '../widgets/app_text_field.dart';
import 'vault_screen.dart';

// Two-step recovery screen.
// Step 1: the user types their 12-word recovery phrase.
// Step 2: set a new master password.
// On completion the wrappedKeyFromPassword is re-encrypted with the new
// password-derived key, and the user is dropped into the vault.
class ForgotPasswordScreen extends StatefulWidget {
  final User user;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const ForgotPasswordScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Which step is active: 0 = recovery phrase, 1 = new password
  int _step = 0;

  final _phraseController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  // Vault key recovered via the recovery phrase, used in step 2
  String? _recoveredVaultKey;

  bool _phraseHidden = false;
  bool _newPasswordHidden = true;
  bool _confirmHidden = true;
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _verifyPhrase() async {
    String phrase = _phraseController.text.trim();

    if (phrase.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your recovery phrase.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    String? vaultKey = await widget.authService.unlockWithRecovery(
      widget.user,
      phrase,
    );

    if (!mounted) return;

    if (vaultKey == null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Recovery phrase is incorrect. Check spelling and word order.';
      });
      return;
    }

    // Phrase is correct — move to the new password step
    setState(() {
      _recoveredVaultKey = vaultKey;
      _isLoading = false;
      _step = 1;
      _errorMessage = '';
    });
  }

  Future<void> _resetPassword() async {
    String newPassword = _newPasswordController.text.trim();
    String confirm = _confirmController.text.trim();

    if (newPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a new master password.';
      });
      return;
    }

    if (newPassword != confirm) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Re-wrap the vault key with the new password
    await widget.authService.resetPassword(
      user: widget.user,
      newPassword: newPassword,
      vaultKey: _recoveredVaultKey!,
    );

    if (!mounted) return;

    // Reload user from DB to get updated wrappedKeyFromPassword
    User? updatedUser = await widget.authService.getCurrentUser();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => VaultScreen(
          credentialRepository: widget.credentialRepository,
          encryptionService: widget.encryptionService,
          aesKey: _recoveredVaultKey!,
          authService: widget.authService,
          user: updatedUser ?? widget.user,
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Shared.textPrimary),
              ),

              const SizedBox(height: 12),

              if (_step == 0) _buildPhraseStep(),
              if (_step == 1) _buildNewPasswordStep(),
            ],
          ),
        ),
      ),
    );
  }

  // Step 1 — enter recovery phrase
  Widget _buildPhraseStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recover Your Account',
          style: TextStyle(
            color: Shared.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Enter your 12-word recovery phrase exactly as you wrote it down.',
          style: TextStyle(
            color: Shared.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 28),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Recovery Phrase',
                style: TextStyle(color: Shared.textSecondary, fontSize: 14),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Shared.surface,
                borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
                border: Border.all(color: Shared.border),
              ),
              child: TextField(
                controller: _phraseController,
                obscureText: _phraseHidden,
                maxLines: _phraseHidden ? 1 : 4,
                style: const TextStyle(color: Shared.textPrimary),
                decoration: InputDecoration(
                  hintText: 'word1 word2 word3 ...',
                  hintStyle: const TextStyle(color: Shared.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _phraseHidden = !_phraseHidden;
                      });
                    },
                    icon: Icon(
                      _phraseHidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Shared.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: const TextStyle(color: Shared.error, fontSize: 13),
          ),
        ],

        const SizedBox(height: 28),

        _isLoading
            ? const Center(child: CircularProgressIndicator(color: Shared.gold))
            : PrimaryButton(label: 'Verify Phrase', onPressed: _verifyPhrase),
      ],
    );
  }

  // Step 2 — set new password
  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set New Password',
          style: TextStyle(
            color: Shared.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Choose a strong new master password for your vault.',
          style: TextStyle(
            color: Shared.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 28),

        AppTextField(
          label: 'New Master Password',
          controller: _newPasswordController,
          hintText: 'Enter new password',
          obscureText: _newPasswordHidden,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _newPasswordHidden = !_newPasswordHidden;
              });
            },
            icon: Icon(
              _newPasswordHidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Shared.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 20),

        AppTextField(
          label: 'Confirm Password',
          controller: _confirmController,
          hintText: 'Re-enter new password',
          obscureText: _confirmHidden,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _confirmHidden = !_confirmHidden;
              });
            },
            icon: Icon(
              _confirmHidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Shared.textSecondary,
            ),
          ),
        ),

        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: const TextStyle(color: Shared.error, fontSize: 13),
          ),
        ],

        const SizedBox(height: 28),

        _isLoading
            ? const Center(child: CircularProgressIndicator(color: Shared.gold))
            : PrimaryButton(label: 'Reset Password', onPressed: _resetPassword),
      ],
    );
  }
}
