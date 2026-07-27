import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../theme/shared.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'pin_lock_screen.dart';

// Shown when biometric Quick Access is enabled — it's the primary unlock
// method, so this screen tries it right away. Falls back to PIN (if also
// enabled) or the master password.
class BioLockScreen extends StatefulWidget {
  final User user;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const BioLockScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
  });

  @override
  State<BioLockScreen> createState() => _BioLockScreenState();
}

class _BioLockScreenState extends State<BioLockScreen> {
  bool isChecking = false;

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool get _bioAvailable => widget.authService.bioAttemptsRemaining > 0;
  bool get _pinAvailable =>
      widget.user.pinEnabled && widget.authService.pinAttemptsRemaining > 0;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  // Attempt biometric unlock. On success, load the vault key from secure
  // storage and open the vault.
  Future<void> _tryBiometric() async {
    setState(() {
      isChecking = true;
    });

    bool authenticated = false;
    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Anubis to access your vault',
      );
    } catch (_) {
      // Biometric not available or cancelled — treat as a failed attempt,
      // same as an explicit no-match.
    }

    if (!mounted) return;

    if (authenticated) {
      String? vaultKey = await widget.authService.getStoredVaultKey();
      if (!mounted) return;

      if (vaultKey != null) {
        await widget.authService.markUnlockedThisBoot();
        _openVault(vaultKey);
        return;
      }
    } else {
      widget.authService.recordFailedBiometricAttempt();
    }

    setState(() {
      isChecking = false;
    });

    if (!_bioAvailable && !_pinAvailable) {
      _showLockedOutDialog();
    }
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

  void _switchToPin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PinLockScreen(
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
              const SizedBox(height: 24),

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
                _bioAvailable
                    ? 'Use biometrics to unlock'
                    : 'No biometric tries left',
                style: const TextStyle(
                  color: Shared.textSecondary,
                  fontSize: 14,
                ),
              ),

              // Everything above and below this is a fixed size, so the
              // icon always lands in the middle of whatever space is left,
              // no matter how tall the top or bottom blocks are.
              Expanded(
                child: Center(
                  child: Icon(
                    Icons.fingerprint,
                    color: Shared.gold,
                    size: 96,
                  ),
                ),
              ),

              if (isChecking)
                const CircularProgressIndicator(color: Shared.gold)
              else if (_bioAvailable)
                TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(
                    Icons.refresh,
                    color: Shared.gold,
                    size: 20,
                  ),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(color: Shared.gold, fontSize: 14),
                  ),
                ),

              const SizedBox(height: 8),

              if (widget.user.pinEnabled) ...[
                TextButton(
                  onPressed: _switchToPin,
                  child: const Text(
                    'Use PIN instead',
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
            ],
          ),
        ),
      ),
    );
  }
}
