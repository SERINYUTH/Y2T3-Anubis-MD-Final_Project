import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/credential.dart';
import '../../repositories/credential_repository.dart';
import 'add_edit_screen.dart';
import '../theme/shared.dart';
import '../theme/category_style.dart';

// Shows one credential in read only form, with copy buttons
// and a pencil icon that opens the Edit screen
class DetailScreen extends StatefulWidget {
  final Credential credential;
  final CredentialRepository credentialRepository;
  final encryptionService;
  final String aesKey;

  const DetailScreen({
    super.key,
    required this.credential,
    required this.credentialRepository,
    required this.encryptionService,
    required this.aesKey,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  // True while the credential is being decrypted
  bool isLoading = true;

  // The decrypted fields, ready to display
  CredentialData? data;

  bool passwordHidden = true;

  @override
  void initState() {
    super.initState();
    loadCredentialData();
  }

  // Decrypts the credential passed into this screen
  Future<void> loadCredentialData() async {
    String decryptedJsonString = await widget.encryptionService.decrypt(
      widget.credential.encryptedData,
      widget.aesKey,
    );

    CredentialData result = CredentialData.fromJsonString(decryptedJsonString);

    setState(() {
      data = result;
      isLoading = false;
    });
  }

  // Copies text to the clipboard, shows a toast
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
  }

  // Opens the Add/Edit screen in Edit mode, then goes back to the vault
  // once the user is done, since the credential may have changed
  Future<void> openEditScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditScreen(
          credentialRepository: widget.credentialRepository,
          encryptionService: widget.encryptionService,
          aesKey: widget.aesKey,
          existingCredential: widget.credential,
        ),
      ),
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Turns July 12 2026 into a simple date string, no third party package needed
  String formatDate(DateTime date) {
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    String month = months[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading == true) {
      return const Scaffold(
        backgroundColor: Shared.background,
        body: Center(child: CircularProgressIndicator(color: Shared.gold)),
      );
    }

    CredentialData credentialData = data!;

    return Scaffold(
      backgroundColor: Shared.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row, back arrow plus pencil edit icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Shared.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: openEditScreen,
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Shared.textPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Category icon plus the credential title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: getCategoryColor(widget.credential.category),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      getCategoryIcon(widget.credential.category),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      credentialData.title,
                      style: const TextStyle(
                        color: Shared.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              buildFieldCard(
                label: 'Username',
                value: credentialData.username,
                onCopy: () {
                  copyToClipboard(credentialData.username);
                },
              ),

              const SizedBox(height: 12),

              buildPasswordCard(credentialData.password),

              const SizedBox(height: 12),

              buildFieldCard(
                label: 'URL',
                value: credentialData.url,
                onCopy: () {
                  copyToClipboard(credentialData.url);
                },
              ),

              const SizedBox(height: 24),

              Text(
                'Last updated ${formatDate(widget.credential.updatedAt)}',
                style: const TextStyle(
                  color: Shared.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A read only field card, used for Username and URL
  Widget buildFieldCard({
    required String label,
    required String value,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Shared.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Shared.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Shared.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Shared.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined, color: Shared.textSecondary),
          ),
        ],
      ),
    );
  }

  // The password field, masked by default with an eye icon plus a copy icon
  Widget buildPasswordCard(String password) {
    String displayText = passwordHidden ? '•' * password.length : password;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Shared.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Shared.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password',
                  style: TextStyle(color: Shared.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  displayText,
                  style: const TextStyle(
                    color: Shared.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                passwordHidden = passwordHidden == false;
              });
            },
            icon: Icon(
              passwordHidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Shared.textSecondary,
            ),
          ),
          IconButton(
            onPressed: () {
              copyToClipboard(password);
            },
            icon: const Icon(Icons.copy_outlined, color: Shared.textSecondary),
          ),
        ],
      ),
    );
  }
}
