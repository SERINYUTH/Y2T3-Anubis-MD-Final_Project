import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../../services/auth_service.dart';
import '../theme/shared.dart';
import 'vault_screen.dart';
import 'password_generator_screen.dart';
import 'setting_screen.dart';

// HomeScreen owns the bottom nav and passes shared dependencies down
// to each tab. Sign out pops all the way back to root via onSignOut.
class HomeScreen extends StatefulWidget {
  final User user;
  final String aesKey;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;

  const HomeScreen({
    super.key,
    required this.user,
    required this.aesKey,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _handleSignOut() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      VaultScreen(
        user: widget.user,
        aesKey: widget.aesKey,
        authService: widget.authService,
        credentialRepository: widget.credentialRepository,
        encryptionService: widget.encryptionService,
      ),
      const PasswordGeneratorScreen(),
      SettingScreen(
        user: widget.user,
        aesKey: widget.aesKey,
        authService: widget.authService,
        credentialRepository: widget.credentialRepository,
        encryptionService: widget.encryptionService,
        onSignOut: _handleSignOut,
      ),
    ];

    return Scaffold(
      backgroundColor: Shared.background,
      // Keep all tabs alive so state (scroll position, search) is preserved
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Shared.surface,
        selectedItemColor: Shared.gold,
        unselectedItemColor: Shared.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_outlined),
            activeIcon: Icon(Icons.lock),
            label: 'Vault',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.password_outlined),
            activeIcon: Icon(Icons.password),
            label: 'Generator',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
