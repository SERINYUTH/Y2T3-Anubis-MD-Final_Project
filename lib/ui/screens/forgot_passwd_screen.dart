import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import '../widgets/app_text_field.dart';
import 'home_screen.dart';

// Two-step recovery screen.
// Step 1: the user types their recovery key.
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
  // Which step is active: 0 = recovery key, 1 = new password
  int _step = 0;

  final _recoveryKeyController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  // Vault key recovered via the recovery key, used in step 2
  String? _recoveredVaultKey;

  bool _recoveryKeyHidden = false;
  bool _newPasswordHidden = true;
  bool _confirmHidden = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() => setState(() {}));
  }

  Future<void> _verifyRecoveryKey() async {
    String recoveryKey = _recoveryKeyController.text.trim();

    if (recoveryKey.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your recovery key.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    String? vaultKey = await widget.authService.unlockWithRecovery(
      widget.user,
      recoveryKey,
    );

    if (!mounted) return;

    if (vaultKey == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Recovery key is incorrect. Check for typos.';
      });
      return;
    }

    // Key is correct — move to the new password step
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
        builder: (_) => HomeScreen(
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

  int _strengthScore(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*()\-_=+\[\]{}|;:,.<>?]').hasMatch(password)) score++;
    return score.clamp(0, 7);
  }

  String _strengthLabel(int score) {
    if (score <= 2) return 'Weak';
    if (score <= 4) return 'Fair';
    if (score <= 5) return 'Good';
    return 'Strong';
  }

  Color _strengthColor(int score) {
    if (score <= 2) return Shared.error;
    if (score <= 4) return const Color(0xFFFF9800);
    if (score <= 5) return const Color(0xFFFFEB3B);
    return Shared.success;
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

              if (_step == 0) _buildRecoveryKeyStep(),
              if (_step == 1) _buildNewPasswordStep(),
            ],
          ),
        ),
      ),
    );
  }

  // Step 1 — enter recovery key
  Widget _buildRecoveryKeyStep() {
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
          'Enter your recovery key exactly as it was shown to you.',
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
                'Recovery Key',
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
                controller: _recoveryKeyController,
                obscureText: _recoveryKeyHidden,
                style: const TextStyle(color: Shared.textPrimary),
                decoration: InputDecoration(
                  hintText: 'XXXX-XXXX-XXXX-XXXX',
                  hintStyle: const TextStyle(color: Shared.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _recoveryKeyHidden = !_recoveryKeyHidden;
                      });
                    },
                    icon: Icon(
                      _recoveryKeyHidden
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
            : PrimaryButton(
                label: 'Verify Recovery Key',
                onPressed: _verifyRecoveryKey,
              ),
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

        if (_newPasswordController.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _strengthScore(_newPasswordController.text) / 7,
                    minHeight: 5,
                    backgroundColor: Shared.border,
                    valueColor: AlwaysStoppedAnimation(
                      _strengthColor(
                        _strengthScore(_newPasswordController.text),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _strengthLabel(_strengthScore(_newPasswordController.text)),
                style: TextStyle(
                  color: _strengthColor(
                    _strengthScore(_newPasswordController.text),
                  ),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],

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
