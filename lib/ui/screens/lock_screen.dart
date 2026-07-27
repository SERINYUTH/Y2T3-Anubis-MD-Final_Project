import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../theme/shared.dart';
import 'forgot_passwd_screen.dart';
import 'home_screen.dart';

// Lock screen shown when the app re-opens and a session already exists.
// The vault key was previously derived and stored in OS secure storage via
// AuthService. This screen just asks for the PIN (or biometrics) to retrieve
// it — no slow PBKDF2 needed here.
class LockScreen extends StatefulWidget {
  final User user;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const LockScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  // The 6 digits the user has typed so far
  final List<String> enteredDigits = [];

  bool showError = false;
  bool isCheckingBiometric = false;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    // Try biometrics immediately if the user enabled them
    if (widget.user.biometricEnabled) {
      _tryBiometric();
    }
  }

  // Attempt biometric unlock. On success, load the vault key from secure
  // storage and open the vault — no PIN entry needed.
  Future<void> _tryBiometric() async {
    setState(() {
      isCheckingBiometric = true;
    });

    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Anubis to access your vault',
      );

      if (!mounted) return;

      if (authenticated) {
        String? vaultKey = await widget.authService.getStoredVaultKey();

        if (!mounted) return;

        if (vaultKey != null) {
          _openVault(vaultKey);
          return;
        }
      }
    } catch (_) {
      // Biometric not available or cancelled — fall through to PIN
    }

    if (mounted) {
      setState(() {
        isCheckingBiometric = false;
      });
    }
  }

  // Called when the user taps a digit on the keypad
  void _onDigitTapped(String digit) {
    if (enteredDigits.length >= 6) return;

    setState(() {
      showError = false;
      enteredDigits.add(digit);
    });

    // Auto-submit once 6 digits have been entered
    if (enteredDigits.length == 6) {
      _checkPin();
    }
  }

  // Delete the last digit
  void _onBackspace() {
    if (enteredDigits.isEmpty) return;
    setState(() {
      enteredDigits.removeLast();
      showError = false;
    });
  }

  // Verify the PIN, then load the vault key from secure storage on success
  Future<void> _checkPin() async {
    String pin = enteredDigits.join();
    bool correct = await widget.authService.verifyPin(pin);

    if (!mounted) return;

    if (!correct) {
      setState(() {
        enteredDigits.clear();
        showError = true;
      });
      return;
    }

    String? vaultKey = await widget.authService.getStoredVaultKey();

    if (!mounted) return;

    if (vaultKey == null) {
      // Secure storage was cleared (e.g. device reset) — fall back to login
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    _openVault(vaultKey);
  }

  void _openVault(String vaultKey) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
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

  void _openForgotPassword() {
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Image.asset(
                'assets/anubis_app.png',
                width: 90,
                height: 90,
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Anubis',
                style: TextStyle(
                  color: Shared.gold,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Enter your PIN to unlock',
                style: TextStyle(color: Shared.textSecondary, fontSize: 14),
              ),

              const SizedBox(height: 40),

              // PIN dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  bool filled = index < enteredDigits.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? Shared.gold : Colors.transparent,
                      border: Border.all(
                        color: showError ? Shared.error : Shared.border,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              if (showError) ...[
                const SizedBox(height: 12),
                const Text(
                  'Incorrect PIN. Try again.',
                  style: TextStyle(color: Shared.error, fontSize: 13),
                ),
              ],

              const Spacer(flex: 2),

              // Numpad
              _buildNumpad(),

              const SizedBox(height: 24),

              // Biometric button (if enabled)
              if (widget.user.biometricEnabled) ...[
                TextButton.icon(
                  onPressed: isCheckingBiometric ? null : _tryBiometric,
                  icon: const Icon(
                    Icons.fingerprint,
                    color: Shared.gold,
                    size: 22,
                  ),
                  label: const Text(
                    'Use biometrics',
                    style: TextStyle(color: Shared.gold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              TextButton(
                onPressed: _openForgotPassword,
                child: const Text(
                  'Forgot PIN?',
                  style: TextStyle(color: Shared.textSecondary, fontSize: 13),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((label) {
              if (label == '') {
                return const SizedBox(width: 80, height: 64);
              }

              if (label == '⌫') {
                return _buildKey(
                  label: label,
                  onTap: _onBackspace,
                  isAction: true,
                );
              }

              return _buildKey(
                label: label,
                onTap: () => _onDigitTapped(label),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKey({
    required String label,
    required VoidCallback onTap,
    bool isAction = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 64,
        decoration: BoxDecoration(
          color: isAction ? Colors.transparent : Shared.surface,
          borderRadius: BorderRadius.circular(12),
          border: isAction ? null : Border.all(color: Shared.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isAction ? Shared.textSecondary : Shared.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
