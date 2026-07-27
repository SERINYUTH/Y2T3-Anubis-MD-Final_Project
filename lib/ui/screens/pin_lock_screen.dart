import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../theme/shared.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'bio_lock_screen.dart';

// Shown when PIN is the method in use — either because biometric isn't
// enabled at all, or because the user switched over from BioLockScreen.
// No biometric option appears here unless biometric is enabled, in which
// case a link back to it is offered.
class PinLockScreen extends StatefulWidget {
  final User user;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const PinLockScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final List<String> enteredDigits = [];

  bool showError = false;

  bool get _pinAvailable => widget.authService.pinAttemptsRemaining > 0;
  bool get _bioAvailable =>
      widget.user.biometricEnabled && widget.authService.bioAttemptsRemaining > 0;

  void _onDigitTapped(String digit) {
    if (!_pinAvailable) return;
    if (enteredDigits.length >= 6) return;

    setState(() {
      showError = false;
      enteredDigits.add(digit);
    });

    if (enteredDigits.length == 6) {
      _checkPin();
    }
  }

  void _onBackspace() {
    if (enteredDigits.isEmpty) return;
    setState(() {
      enteredDigits.removeLast();
      showError = false;
    });
  }

  Future<void> _checkPin() async {
    String pin = enteredDigits.join();
    bool correct = await widget.authService.verifyPin(pin);

    if (!mounted) return;

    if (!correct) {
      int remaining = widget.authService.recordFailedPinAttempt();
      setState(() {
        enteredDigits.clear();
        showError = true;
      });

      if (remaining <= 0 && !_bioAvailable) {
        _showLockedOutDialog();
      }
      return;
    }

    String? vaultKey = await widget.authService.getStoredVaultKey();

    if (!mounted) return;

    if (vaultKey == null) {
      // Secure storage was cleared (e.g. device reset) — fall back to the
      // master password flow entirely.
      _openMasterPassword();
      return;
    }

    await widget.authService.markUnlockedThisBoot();
    _openVault(vaultKey);
  }

  void _showLockedOutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Shared.surface,
        title: const Text(
          'Too Many Attempts',
          style: TextStyle(color: Shared.error),
        ),
        content: const Text(
          "You're out of tries for Quick Access. Enter your master "
          'password to get back into the vault — this also resets '
          'Quick Access.',
          style: TextStyle(color: Shared.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openMasterPassword();
            },
            child: const Text(
              'Enter Master Password',
              style: TextStyle(color: Shared.gold),
            ),
          ),
        ],
      ),
    );
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

  void _openMasterPassword() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          user: widget.user,
          authService: widget.authService,
          credentialRepository: widget.credentialRepository,
          encryptionService: widget.encryptionService,
        ),
      ),
      (route) => false,
    );
  }

  void _switchToBiometric() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BioLockScreen(
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

              Image.asset('assets/anubis_app.png', width: 90, height: 90),

              const SizedBox(height: 16),

              const Text(
                'Anubis',
                style: TextStyle(
                  color: Shared.gold,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _pinAvailable ? 'Enter your PIN to unlock' : 'No PIN tries left',
                style: const TextStyle(
                  color: Shared.textSecondary,
                  fontSize: 14,
                ),
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
                Text(
                  _pinAvailable
                      ? 'Incorrect PIN. ${widget.authService.pinAttemptsRemaining} tries left.'
                      : 'No PIN tries left.',
                  style: const TextStyle(color: Shared.error, fontSize: 13),
                ),
              ],

              const Spacer(flex: 2),

              _buildNumpad(),

              const SizedBox(height: 24),

              if (_bioAvailable) ...[
                TextButton(
                  onPressed: _switchToBiometric,
                  child: const Text(
                    'Use Biometrics instead',
                    style: TextStyle(color: Shared.gold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 4),
              ],

              TextButton(
                onPressed: _openMasterPassword,
                child: const Text(
                  'Use Master Password',
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
    bool disabled = !isAction && !_pinAvailable;
    return GestureDetector(
      onTap: disabled ? null : onTap,
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
            color: disabled
                ? Shared.border
                : (isAction ? Shared.textSecondary : Shared.textPrimary),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
