import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import 'bio_lock_screen.dart';
import 'pin_lock_screen.dart';

// Entry point RootScreen shows when a Quick Access session is still trusted.
// BioLockScreen is shown first. PIN only opens first when biometric was never enabled at all.
class LockScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (user.biometricEnabled) {
      return BioLockScreen(
        user: user,
        authService: authService,
        credentialRepository: credentialRepository,
        encryptionService: encryptionService,
      );
    }

    return PinLockScreen(
      user: user,
      authService: authService,
      credentialRepository: credentialRepository,
      encryptionService: encryptionService,
    );
  }
}
