import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import 'pin_setup_screen.dart';

// Settings-facing Quick Access screen. Reused after registration to let the
// user turn PIN and/or biometric unlock on or off. Unlike the registration
// flow (QuickAccessSetupScreen), this screen doesn't chain into the vault —
// the user is already inside it — it just applies changes and pops back.
class QuickAccessScreen extends StatefulWidget {
  final User user;
  final String vaultKey;
  final AuthService authService;

  const QuickAccessScreen({
    super.key,
    required this.user,
    required this.vaultKey,
    required this.authService,
  });

  @override
  State<QuickAccessScreen> createState() => _QuickAccessScreenState();
}

class _QuickAccessScreenState extends State<QuickAccessScreen> {
  bool checkingDevice = true;
  bool deviceSupportsBiometric = false;

  bool pinOn = false;
  bool bioOn = false;

  bool isBusy = false;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    pinOn = widget.user.pinEnabled;
    bioOn = widget.user.biometricEnabled;
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

  // Keeps the cached vault key in sync with whether Quick Access is on.
  // Turning the last method off wipes the cached key (nothing left that
  // should be able to fetch it without the master password). Turning the
  // first method on caches it again so Quick Access can actually work.
  Future<void> _syncVaultKeyStorage() async {
    if (widget.user.hasQuickAccess) {
      await widget.authService.storeVaultKey(widget.vaultKey);
      await widget.authService.markUnlockedThisBoot();
    } else {
      await widget.authService.clearStoredVaultKey();
    }
  }

  // Toggling PIN on walks the user through creating one first — it only
  // switches on if a PIN was actually saved. Toggling off just turns it off.
  Future<void> _onPinToggle(bool value) async {
    if (!value) {
      setState(() => isBusy = true);
      await widget.authService.setPinEnabled(false);
      widget.user.pinEnabled = false;
      await _syncVaultKeyStorage();
      if (!mounted) return;
      setState(() {
        pinOn = false;
        isBusy = false;
      });
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

    if (created) {
      await _syncVaultKeyStorage();
    }
    if (!mounted) return;
    setState(() => pinOn = created);
  }

  // Toggling biometric on requires proving it actually works on this
  // device before we trust it. Toggling off needs no proof.
  Future<void> _onBioToggle(bool value) async {
    if (!value) {
      setState(() => isBusy = true);
      await widget.authService.setBiometricEnabled(false);
      widget.user.biometricEnabled = false;
      await _syncVaultKeyStorage();
      if (!mounted) return;
      setState(() {
        bioOn = false;
        isBusy = false;
      });
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
      await _syncVaultKeyStorage();
    }

    if (!mounted) return;
    setState(() {
      bioOn = confirmed;
      isBusy = false;
    });
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
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Shared.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Quick Access',
                          style: TextStyle(
                            color: Shared.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Optional. Unlock with a fingerprint/Face ID or a '
                        'short PIN instead of typing your master password '
                        'every time. Turn both off and your master '
                        'password becomes the only way in again.',
                        style: TextStyle(
                          color: Shared.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
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
                                      'PIN and biometric each get 3 tries. '
                                      'Run out and you\'ll need your master '
                                      'password to get back in — that also '
                                      'resets the tries. Restarting your '
                                      'phone always asks for the master '
                                      'password once too.',
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
                            label: 'Done',
                            onPressed: () => Navigator.pop(context),
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
