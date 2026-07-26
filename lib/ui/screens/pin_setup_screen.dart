import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../theme/shared.dart';
import 'bio_screen.dart';

// PIN setup screen, used both during registration and when changing the PIN.
// When isChangingPin is true it simply saves the new PIN and pops back.
// When isChangingPin is false (registration flow) it advances to BioScreen.
class PinSetupScreen extends StatefulWidget {
  final User user;
  final String vaultKey;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;
  final bool isChangingPin;

  const PinSetupScreen({
    super.key,
    required this.user,
    required this.vaultKey,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
    this.isChangingPin = false,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  // Step 0 = enter PIN, Step 1 = confirm PIN
  int _step = 0;

  final List<String> _firstPin = [];
  final List<String> _confirmPin = [];

  bool _showError = false;
  bool _isSaving = false;

  List<String> get _activePin => _step == 0 ? _firstPin : _confirmPin;

  void _onDigitTapped(String digit) {
    if (_activePin.length >= 6) return;

    setState(() {
      _showError = false;
      _activePin.add(digit);
    });

    if (_activePin.length == 6) {
      if (_step == 0) {
        // Move to confirmation step
        setState(() {
          _step = 1;
        });
      } else {
        _confirmAndSave();
      }
    }
  }

  void _onBackspace() {
    if (_activePin.isEmpty) return;
    setState(() {
      _activePin.removeLast();
      _showError = false;
    });
  }

  Future<void> _confirmAndSave() async {
    // PINs must match
    if (_firstPin.join() != _confirmPin.join()) {
      setState(() {
        _showError = true;
        _confirmPin.clear();
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    String pin = _firstPin.join();
    await widget.authService.savePin(pin);
    // Also store the vault key in secure storage so lock screen can retrieve it
    await widget.authService.storeVaultKey(widget.vaultKey);

    if (!mounted) return;

    if (widget.isChangingPin) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated successfully.')),
      );
      return;
    }

    // Registration flow — advance to biometric setup
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BioScreen(
          user: widget.user,
          vaultKey: widget.vaultKey,
          authService: widget.authService,
          credentialRepository: widget.credentialRepository,
          encryptionService: widget.encryptionService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = _step == 0
        ? (widget.isChangingPin ? 'Enter New PIN' : 'Set a PIN')
        : 'Confirm PIN';

    String subtitle = _step == 0
        ? 'Choose a 6-digit PIN to quickly unlock your vault.'
        : 'Enter the same PIN again to confirm.';

    List<String> displayPin = _step == 0 ? _firstPin : _confirmPin;

    return Scaffold(
      backgroundColor: Shared.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              // Back button only in step 1 (go back to re-enter first PIN)
              Align(
                alignment: Alignment.centerLeft,
                child: _step == 1
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _step = 0;
                            _firstPin.clear();
                            _confirmPin.clear();
                            _showError = false;
                          });
                        },
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Shared.textPrimary,
                        ),
                      )
                    : const SizedBox(height: 48),
              ),

              const Spacer(flex: 2),

              Text(
                title,
                style: const TextStyle(
                  color: Shared.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Shared.textSecondary,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 40),

              // Dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  bool filled = index < displayPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? Shared.gold : Colors.transparent,
                      border: Border.all(
                        color: _showError ? Shared.error : Shared.border,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              if (_showError) ...[
                const SizedBox(height: 12),
                const Text(
                  'PINs do not match. Try again.',
                  style: TextStyle(color: Shared.error, fontSize: 13),
                ),
              ],

              const Spacer(flex: 2),

              if (_isSaving)
                const CircularProgressIndicator(color: Shared.gold)
              else
                _buildNumpad(),

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
                return _key(label: label, onTap: _onBackspace, isAction: true);
              }
              return _key(label: label, onTap: () => _onDigitTapped(label));
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _key({
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
