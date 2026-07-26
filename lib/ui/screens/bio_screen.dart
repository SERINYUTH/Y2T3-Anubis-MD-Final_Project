import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/user.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../../services/auth_service.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import 'vault_screen.dart';

// Shown after PIN setup during registration.
// The user can enable biometric unlock here, or skip it.
// Either way they end up on the Vault screen.
class BioScreen extends StatefulWidget {
  final User user;
  final String vaultKey;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const BioScreen({
    super.key,
    required this.user,
    required this.vaultKey,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
  });

  @override
  State<BioScreen> createState() => _BioScreenState();
}

class _BioScreenState extends State<BioScreen> {
  bool isSaving = false;
  bool deviceSupported = false;
  bool checking = true;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      bool isSupported = await _localAuth.isDeviceSupported();
      setState(() {
        deviceSupported = canCheck && isSupported;
        checking = false;
      });
    } catch (_) {
      setState(() {
        deviceSupported = false;
        checking = false;
      });
    }
  }

  Future<void> _enableBiometrics() async {
    setState(() {
      isSaving = true;
    });

    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirm biometric to enable it for Anubis',
      );

      if (!mounted) return;

      if (authenticated) {
        await widget.authService.setBiometricEnabled(true);
        _goToVault();
        return;
      }
    } catch (_) {
      // User cancelled or sensor failed — treat as skip
    }

    if (mounted) {
      setState(() {
        isSaving = false;
      });
    }
  }

  void _skipBiometrics() {
    _goToVault();
  }

  void _goToVault() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => VaultScreen(
          credentialRepository: widget.credentialRepository,
          encryptionService: widget.encryptionService,
          aesKey: widget.vaultKey,
          authService: widget.authService,
          user: widget.user,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(
        backgroundColor: Shared.background,
        body: Center(child: CircularProgressIndicator(color: Shared.gold)),
      );
    }

    return Scaffold(
      backgroundColor: Shared.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              const Icon(Icons.fingerprint, color: Shared.gold, size: 64),

              const SizedBox(height: 24),

              const Text(
                'Enable Biometrics',
                style: TextStyle(
                  color: Shared.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                deviceSupported
                    ? 'Use fingerprint or Face ID to unlock your vault quickly — no PIN needed each time.'
                    : 'Your device does not support biometric authentication. You can still use your PIN to unlock.',
                style: const TextStyle(
                  color: Shared.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),

              if (deviceSupported) ...[
                isSaving
                    ? const Center(
                        child: CircularProgressIndicator(color: Shared.gold),
                      )
                    : PrimaryButton(
                        label: 'Enable Biometrics',
                        onPressed: _enableBiometrics,
                      ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                height: Shared.buttonHeight,
                child: OutlinedButton(
                  onPressed: _skipBiometrics,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Shared.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        Shared.cardBorderRadius,
                      ),
                    ),
                  ),
                  child: Text(
                    deviceSupported ? 'Skip for now' : 'Continue',
                    style: const TextStyle(color: Shared.textSecondary),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
