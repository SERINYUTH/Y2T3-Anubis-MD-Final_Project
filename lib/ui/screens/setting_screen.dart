import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/user.dart';
import '../../models/credential.dart';
import '../../models/category.dart';
import '../../repositories/credential_repository.dart';
import '../../services/encryption_service.dart';
import '../../services/auth_service.dart';
import '../theme/shared.dart';
import 'pin_setup_screen.dart';
import 'quick_access_screen.dart';

// Settings screen: change PIN, export vault, import vault, sign out.
class SettingScreen extends StatefulWidget {
  final User user;
  final String aesKey;
  final AuthService authService;
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;
  final VoidCallback onSignOut;

  const SettingScreen({
    super.key,
    required this.user,
    required this.aesKey,
    required this.authService,
    required this.credentialRepository,
    required this.encryptionService,
    required this.onSignOut,
  });

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  // ── Export ────────────────────────────────────────────────────────────────
  // Writes an encrypted JSON backup to the app's Documents folder.
  // No external packages needed — just dart:io + path_provider.
  Future<void> _exportVault() async {
    setState(() => _isExporting = true);

    try {
      List<Credential> credentials = await widget.credentialRepository
          .getAllCredentials();

      List<Map<String, dynamic>> rows = credentials
          .map(
            (c) => {
              'id': c.id,
              'encryptedData': c.encryptedData,
              'category': c.category.name,
              'updatedAt': c.updatedAt.toIso8601String(),
            },
          )
          .toList();

      // Wrap with an outer AES layer so the file is useless without
      // the master password.
      String plainJson = jsonEncode({'credentials': rows});
      String encryptedPayload = await widget.encryptionService.encrypt(
        plainJson,
        widget.aesKey,
      );

      Map<String, dynamic> backupObject = {
        'app': 'anubis',
        'schema': 1,
        'salt': widget.user.saltForPassword,
        'wrappedKeyFromPassword': widget.user.wrappedKeyFromPassword,
        'data': encryptedPayload,
      };

      // Write to Documents/anubis_backup.json — no external package needed
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/anubis_backup.json');
      await file.writeAsString(jsonEncode(backupObject));

      if (!mounted) return;
      _showDialog(
        title: 'Export Successful',
        message:
            'Backup saved to:\n${file.path}\n\nKeep this file safe — '
            'it can only be restored with your master password.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      _showDialog(
        title: 'Export Failed',
        message: 'Something went wrong:\n$e',
        isError: true,
      );
    }

    setState(() => _isExporting = false);
  }

  // ── Import ────────────────────────────────────────────────────────────────
  // Reads anubis_backup.json from the same Documents folder.
  // No file picker needed — fixed known location keeps it simple.
  Future<void> _importVault() async {
    setState(() => _isImporting = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/anubis_backup.json');

      if (!await file.exists()) {
        if (!mounted) return;
        _showDialog(
          title: 'No Backup Found',
          message:
              'No backup file found at:\n${file.path}\n\n'
              'Export your vault first to create one.',
          isError: true,
        );
        setState(() => _isImporting = false);
        return;
      }

      String fileContent = await file.readAsString();
      Map<String, dynamic> backupObject = jsonDecode(fileContent);

      if (backupObject['app'] != 'anubis') {
        throw Exception('Not a valid Anubis backup file.');
      }

      String encryptedPayload = backupObject['data'];
      String plainJson = await widget.encryptionService.decrypt(
        encryptedPayload,
        widget.aesKey,
      );

      Map<String, dynamic> payload = jsonDecode(plainJson);
      List<dynamic> rows = payload['credentials'];

      int imported = 0;
      for (var row in rows) {
        Credential credential = Credential(
          id: row['id'],
          encryptedData: row['encryptedData'],
          category: CredentialCategory.values.byName(row['category']),
          updatedAt: DateTime.parse(row['updatedAt']),
        );
        await widget.credentialRepository.saveCredential(credential);
        imported++;
      }

      if (!mounted) return;
      _showDialog(
        title: 'Import Successful',
        message: 'Imported $imported credential(s) from backup.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      _showDialog(
        title: 'Import Failed',
        message:
            'Make sure this is a valid Anubis backup and you are '
            'using the same master password.',
        isError: true,
      );
    }

    setState(() => _isImporting = false);
  }

  // ── Shared dialog ─────────────────────────────────────────────────────────
  void _showDialog({
    required String title,
    required String message,
    required bool isError,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Shared.surface,
        title: Text(
          title,
          style: TextStyle(color: isError ? Shared.error : Shared.success),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Shared.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Shared.gold)),
          ),
        ],
      ),
    );
  }

  // ── Change PIN ────────────────────────────────────────────────────────────
  void _openChangePinFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          user: widget.user,
          vaultKey: widget.aesKey,
          authService: widget.authService,
          isChangingPin: true,
        ),
      ),
    );
  }

  // ── Quick Access ──────────────────────────────────────────────────────────
  Future<void> _openQuickAccess() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickAccessScreen(
          user: widget.user,
          vaultKey: widget.aesKey,
          authService: widget.authService,
        ),
      ),
    );
    // widget.user.biometricEnabled may have changed on that screen —
    // refresh so the subtitle below reflects the current state.
    if (mounted) setState(() {});
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Shared.surface,
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Shared.textPrimary),
        ),
        content: const Text(
          'This will remove your session from this device. Your encrypted '
          'vault data stays on-device. You will need your master password '
          'to log back in.',
          style: TextStyle(color: Shared.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Shared.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.authService.clearStoredVaultKey();
              widget.onSignOut();
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Shared.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Shared.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Settings',
                style: TextStyle(
                  color: Shared.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Security ──────────────────────────────────────────
                      _sectionLabel('Security'),

                      _settingTile(
                        icon: Icons.pin_outlined,
                        title: 'Change PIN',
                        subtitle: 'Update your 6-digit unlock PIN',
                        onTap: _openChangePinFlow,
                      ),

                      _settingTile(
                        icon: Icons.fingerprint,
                        title: 'Quick Access',
                        subtitle: () {
                          List<String> on = [
                            if (widget.user.pinEnabled) 'PIN',
                            if (widget.user.biometricEnabled) 'Biometric',
                          ];
                          return on.isEmpty
                              ? 'Off — master password only'
                              : 'On — ${on.join(' + ')}';
                        }(),
                        onTap: _openQuickAccess,
                      ),

                      // ── Backup & Restore ──────────────────────────────────
                      const SizedBox(height: 20),
                      _sectionLabel('Backup & Restore'),

                      _settingTile(
                        icon: Icons.upload_outlined,
                        title: 'Export Vault',
                        subtitle: 'Save encrypted backup to Documents folder',
                        onTap: _isExporting ? null : _exportVault,
                        trailing: _isExporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Shared.gold,
                                ),
                              )
                            : null,
                      ),

                      _settingTile(
                        icon: Icons.download_outlined,
                        title: 'Import Vault',
                        subtitle: 'Restore from Documents/anubis_backup.json',
                        onTap: _isImporting ? null : _importVault,
                        trailing: _isImporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Shared.gold,
                                ),
                              )
                            : null,
                      ),

                      // ── Account ───────────────────────────────────────────
                      const SizedBox(height: 20),
                      _sectionLabel('Account'),

                      _settingTile(
                        icon: Icons.logout,
                        title: 'Sign Out',
                        subtitle: 'Remove session from this device',
                        onTap: _confirmSignOut,
                        iconColor: Shared.error,
                        titleColor: Shared.error,
                      ),

                      const SizedBox(height: 32),

                      const Center(
                        child: Text(
                          'Anubis • Local-first password manager',
                          style: TextStyle(
                            color: Shared.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Shared.gold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
    Color iconColor = Shared.gold,
    Color titleColor = Shared.textPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Shared.surface,
          borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
          border: Border.all(color: Shared.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
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
            trailing ??
                const Icon(
                  Icons.chevron_right,
                  color: Shared.textSecondary,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}
