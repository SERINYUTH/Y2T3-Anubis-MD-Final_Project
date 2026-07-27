import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/user.dart';
import '../../repositories/credential_repository.dart';
import '../../services/auth_service.dart';
import '../../services/encryption_service.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import 'pin_setup_screen.dart';
import 'home_screen.dart';

// Shown once, right after registration (after the recovery key).
class QuickAccessSetupScreen extends StatefulWidget {
  final User user;
  final String vaultKey;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const QuickAccessSetupScreen({
    super.key,
    required this.user,
    required this.vaultKey,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
  });

  @override
  State<QuickAccessSetupScreen> createState() => _QuickAccessSetupScreenState();
}

class _QuickAccessSetupScreenState extends State<QuickAccessSetupScreen> {
  bool checkingDevice = true;
  bool deviceSupportsBiometric = false;

  bool pinOn = false;
  bool bioOn = false;

  bool isBusy = false;

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
        deviceSupportsBiometric = canCheck && isSupported;
        checkingDevice = false;
      });
    } catch (_) {
      setState(() {
        deviceSupportsBiometric = false;
        checkingDevice = false;
      });
    }
  }

  // Toggling PIN on immediately walks the user through creating one.
  // Toggling it off just turns it off, nothing to confirm.
  Future<void> _onPinToggle(bool value) async {
    if (!value) {
      setState(() => pinOn = false);
      return;
    }

    bool created =
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PinSetupScreen(
              user: widget.user,
              vaultKey: widget.vaultKey,
              authService: widget.authService,
            ),
          ),
        ) ??
        false;

    if (!mounted) return;
    setState(() => pinOn = created);
  }

  // Toggling biometric on requires proving it actually works on this
  // device before we trust it. Toggling off needs no proof.
  Future<void> _onBioToggle(bool value) async {
    if (!value) {
      await widget.authService.setBiometricEnabled(false);
      widget.user.biometricEnabled = false;
      setState(() => bioOn = false);
      return;
    }

    setState(() => isBusy = true);

    bool confirmed = false;
    try {
      confirmed = await _localAuth.authenticate(
        localizedReason: 'Confirm biometric to enable Quick Access',
      );
    } catch (_) {
      confirmed = false;
    }

    if (confirmed) {
      await widget.authService.setBiometricEnabled(true);
      widget.user.biometricEnabled = true;
    }

    if (!mounted) return;
    setState(() {
      bioOn = confirmed;
      isBusy = false;
    });
  }

  Future<void> _finish() async {
    setState(() => isBusy = true);

    // Only keep the vault key retrievable on-device if at least one
    // Quick Access method is on. Otherwise the master password stays the
    // only way in, so there is nothing to leave lying around for later.
    if (widget.user.hasQuickAccess) {
      await widget.authService.storeVaultKey(widget.vaultKey);
      await widget.authService.markUnlockedThisBoot();
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
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
    return Scaffold(
      backgroundColor: Shared.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: checkingDevice
              ? const Center(
                  child: CircularProgressIndicator(color: Shared.gold),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set Up Quick Access',
                      style: TextStyle(
                        color: Shared.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '(OPTIONAL) Quick Access with a Fingerprint/Face ID or a PIN.'
                      'Leave both off and your master password will always be what unlocks the vault.',
                      style: TextStyle(
                        color: Shared.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _optionTile(
                              icon: Icons.pin_outlined,
                              title: 'PIN',
                              subtitle: 'Unlock with a 6-digit PIN',
                              value: pinOn,
                              onChanged: isBusy ? null : _onPinToggle,
                            ),
                            const SizedBox(height: 12),
                            _optionTile(
                              icon: Icons.fingerprint,
                              title: 'Biometric',
                              subtitle: deviceSupportsBiometric
                                  ? 'Unlock with fingerprint or Face ID'
                                  : 'Not supported on this device',
                              value: bioOn,
                              onChanged: (deviceSupportsBiometric && !isBusy)
                                  ? _onBioToggle
                                  : null,
                            ),

                            const SizedBox(height: 20),

                            // The security cut this convenience makes.
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Shared.surface,
                                borderRadius: BorderRadius.circular(
                                  Shared.cardBorderRadius,
                                ),
                                border: Border.all(
                                  color: Shared.goldDark.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Shared.gold,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Security note: PIN and biometric are '
                                      'shortcuts, not as strong as your '
                                      'master password. Anyone who gets '
                                      'past them (or your phone) reaches '
                                      'your vault. Each gets 3 tries, then '
                                      'the master password is required. '
                                      'Same after every restart.',
                                      style: TextStyle(
                                        color: Shared.textSecondary,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    isBusy
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Shared.gold,
                            ),
                          )
                        : PrimaryButton(
                            label: widget.user.hasQuickAccess
                                ? 'Continue'
                                : 'Skip for now',
                            onPressed: _finish,
                          ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Shared.surface,
        borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
        border: Border.all(color: Shared.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: Shared.gold, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Shared.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Shared.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Shared.gold,
            activeTrackColor: Shared.goldDark,
            inactiveThumbColor: Shared.textSecondary,
            inactiveTrackColor: Shared.border,
          ),
        ],
      ),
    );
  }
}
