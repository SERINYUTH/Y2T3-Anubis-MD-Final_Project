import 'package:flutter/material.dart';
import 'data/database.dart';
import 'repositories/credential_repository.dart';
import 'services/encryption_service.dart';
import 'services/auth_service.dart';
import 'models/user.dart';
import 'ui/theme/shared.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/lock_screen.dart';

void main() {
  runApp(const AnubisApp());
}

class AnubisApp extends StatelessWidget {
  const AnubisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anubis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Shared.background,
        colorScheme: const ColorScheme.dark(
          primary: Shared.gold,
          surface: Shared.surface,
        ),
      ),
      // Named route '/' lets VaultScreen's sign-out handler pop to root
      initialRoute: '/',
      routes: {'/': (context) => const RootScreen()},
    );
  }
}

// Decides which screen to show first
// If no account exists yet, shows the Welcome screen
// If an account already exists, a login/lock screen will go here later
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool isLoading = true;
  User? existingUser;
  bool canUseLockScreen = false;

  late AppDatabase appDatabase;
  late CredentialRepository credentialRepository;
  late EncryptionService encryptionService;
  late AuthService authService;

  @override
  void initState() {
    super.initState();

    appDatabase = AppDatabase();
    credentialRepository = CredentialRepository(appDatabase: appDatabase);
    encryptionService = EncryptionService();
    authService = AuthService(appDatabase: appDatabase);

    checkForExistingUser();
  }

  Future<void> checkForExistingUser() async {
    User? user = await authService.getCurrentUser();
    bool hasVaultKeyInStorage = false;
    bool restarted = true;

    if (user != null) {
      hasVaultKeyInStorage = (await authService.getStoredVaultKey()) != null;
      restarted = await authService.deviceRestartedSinceLastUnlock();
    }

    setState(() {
      existingUser = user;
      // Quick Access (PIN/biometric) only takes you straight to the lock
      // screen if it's actually turned on, the vault key is cached, and
      // the device hasn't been restarted since the last unlock — a fresh
      // boot always asks for the master password once.
      canUseLockScreen =
          user != null &&
          user.hasQuickAccess &&
          hasVaultKeyInStorage &&
          !restarted;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Shared.background,
        body: Center(child: CircularProgressIndicator(color: Shared.gold)),
      );
    }

    if (existingUser == null) {
      return WelcomeScreen(
        authService: authService,
        credentialRepository: credentialRepository,
        encryptionService: encryptionService,
        existingUser: null,
      );
    }

    // Account exists, Quick Access is on, and this boot session is already
    // trusted → show the lock screen. Otherwise the master password
    // (via WelcomeScreen → LoginScreen) is required.
    if (canUseLockScreen) {
      return LockScreen(
        user: existingUser!,
        authService: authService,
        credentialRepository: credentialRepository,
        encryptionService: encryptionService,
      );
    }

    return WelcomeScreen(
      authService: authService,
      credentialRepository: credentialRepository,
      encryptionService: encryptionService,
      existingUser: existingUser,
    );
  }
}
