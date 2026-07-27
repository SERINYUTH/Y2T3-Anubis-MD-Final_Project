import 'package:anubis/services/encryption_service.dart';
import 'package:flutter/material.dart';
import '../../models/credential.dart';
import '../../models/category.dart';
import '../../repositories/credential_repository.dart';
import '../theme/shared.dart';
import '../widgets/primary_button.dart';
import '../widgets/app_text_field.dart';

// This screen is used both for adding a new credential and for editing
// an existing one, if existingCredential is null this screen is in
// Add mode, if existingCredential is not null this screen is in
// Edit mode and the fields are pre filled with its data

class AddEditScreen extends StatefulWidget {
  final CredentialRepository credentialRepository;
  final EncryptionService encryptionService;
  final String aesKey;

  // If this is null we are adding a new credential
  // If this is not null we are editing this existing credential
  final Credential? existingCredential;

  const AddEditScreen({
    super.key,
    required this.credentialRepository,
    required this.encryptionService,
    required this.aesKey,
    this.existingCredential,
  });

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final titleController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final urlController = TextEditingController();

  CredentialCategory selectedCategory = CredentialCategory.other;

  bool passwordHidden = true;
  bool isSaving = false;
  bool isLoadingExistingData = true;

  int _strengthScore(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*()\-_=+\[\]{}|;:,.<>?]').hasMatch(password)) score++;
    return score.clamp(0, 7);
  }

  String _strengthLabel(int score) {
    if (score <= 2) return 'Weak';
    if (score <= 4) return 'Fair';
    if (score <= 5) return 'Good';
    return 'Strong';
  }

  Color _strengthColor(int score) {
    if (score <= 2) return Shared.error;
    if (score <= 4) return const Color(0xFFFF9800);
    if (score <= 5) return const Color(0xFFFFEB3B);
    return Shared.success;
  }

  @override
  void initState() {
    super.initState();
    loadExistingCredentialIfEditing();
    passwordController.addListener(() => setState(() {}));
  }

  // If we are editing an existing credential this decrypts it and
  // fills the text fields with its current values, if we are adding a
  // new credential there is nothing to load
  Future<void> loadExistingCredentialIfEditing() async {
    if (widget.existingCredential == null) {
      setState(() {
        isLoadingExistingData = false;
      });
      return;
    }

    Credential credential = widget.existingCredential!;

    String decryptedJsonString = await widget.encryptionService.decrypt(
      credential.encryptedData,
      widget.aesKey,
    );

    CredentialData data = CredentialData.fromJsonString(decryptedJsonString);

    setState(() {
      titleController.text = data.title;
      usernameController.text = data.username;
      passwordController.text = data.password;
      urlController.text = data.url;
      selectedCategory = credential.category;
      isLoadingExistingData = false;
    });
  }

  // Turns work into Work for showing in the dropdown
  String capitalize(String text) {
    String firstLetter = text[0].toUpperCase();
    String restOfText = text.substring(1);
    return firstLetter + restOfText;
  }

  // Builds a CredentialData object from whatever is currently typed in
  // the text fields
  CredentialData buildCredentialDataFromFields() {
    return CredentialData(
      title: titleController.text,
      username: usernameController.text,
      password: passwordController.text,
      url: urlController.text,
    );
  }

  // Called when the user taps Save (or the checkmark icon)
  // Encrypts the entered data then saves the credential through the repository
  Future<void> saveCredential() async {
    setState(() {
      isSaving = true;
    });

    CredentialData data = buildCredentialDataFromFields();
    String jsonString = data.toJsonString();
    String encryptedData = await widget.encryptionService.encrypt(
      jsonString,
      widget.aesKey,
    );

    bool isEditing = widget.existingCredential != null;

    String credentialId;
    if (isEditing) {
      credentialId = widget.existingCredential!.id;
    } else {
      credentialId = DateTime.now().microsecondsSinceEpoch.toString();
    }

    Credential credential = Credential(
      id: credentialId,
      encryptedData: encryptedData,
      category: selectedCategory,
      updatedAt: DateTime.now(),
    );

    await widget.credentialRepository.saveCredential(credential);

    setState(() {
      isSaving = false;
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Called when the user taps Delete Credential (only shown in Edit mode)
  Future<void> deleteCredential() async {
    setState(() {
      isSaving = true;
    });

    await widget.credentialRepository.deleteCredential(
      widget.existingCredential!.id,
    );

    setState(() {
      isSaving = false;
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    String password = passwordController.text;
    int score = _strengthScore(password);
    bool isEditing = widget.existingCredential != null;

    if (isLoadingExistingData == true) {
      return const Scaffold(
        backgroundColor: Shared.background,
        body: Center(
          child: CircularProgressIndicator(color: Shared.gold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Shared.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row, back arrow plus checkmark save icon
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
                      onPressed: isSaving ? null : saveCredential,
                      icon: const Icon(Icons.check, color: Shared.gold),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  isEditing ? 'Edit Credential' : 'Add Credential',
                  style: const TextStyle(
                    color: Shared.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 24),

                AppTextField(
                  label: 'Title',
                  controller: titleController,
                  hintText: 'e.g. Google, Netflix',
                ),

                const SizedBox(height: 20),

                AppTextField(
                  label: 'Username',
                  controller: usernameController,
                  hintText: 'Email or username',
                ),

                const SizedBox(height: 20),

                AppTextField(
                  label: 'Password',
                  controller: passwordController,
                  hintText: 'Enter password',
                  obscureText: passwordHidden,
                  suffixIcon: IconButton(
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
                ),

                if (password.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: score / 7,
                            minHeight: 5,
                            backgroundColor: Shared.border,
                            valueColor: AlwaysStoppedAnimation(
                              _strengthColor(score),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _strengthLabel(score),
                        style: TextStyle(
                          color: _strengthColor(score),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 20),

                AppTextField(
                  label: 'URL',
                  controller: urlController,
                  hintText: 'https://example.com',
                ),

                const SizedBox(height: 20),

                buildLabel('Category'),
                buildCategoryDropdown(),

                const SizedBox(height: 28),

                isSaving
                    ? const Center(
                        child: CircularProgressIndicator(color: Shared.gold),
                      )
                    : PrimaryButton(
                        label: 'Save Credential',
                        onPressed: saveCredential,
                      ),

                if (isEditing) ...[
                  const SizedBox(height: 24),
                  buildDeleteButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // A small grey label shown above each field
  Widget buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(color: Shared.textSecondary, fontSize: 14),
      ),
    );
  }

  // The category dropdown, showing every value from the CredentialCategory enum
  Widget buildCategoryDropdown() {
    List<DropdownMenuItem<CredentialCategory>> items = [];

    for (var category in CredentialCategory.values) {
      items.add(
        DropdownMenuItem(
          value: category,
          child: Text(
            capitalize(category.name),
            style: const TextStyle(color: Shared.textPrimary),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Shared.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Shared.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CredentialCategory>(
          value: selectedCategory,
          isExpanded: true,
          dropdownColor: Shared.surface,
          icon: const Icon(Icons.keyboard_arrow_down, color: Shared.textPrimary),
          items: items,
          onChanged: (newValue) {
            setState(() {
              selectedCategory = newValue!;
            });
          },
        ),
      ),
    );
  }

  // The Delete Credential text link, only shown in Edit mode
  Widget buildDeleteButton() {
    return Center(
      child: TextButton(
        onPressed: isSaving ? null : deleteCredential,
        child: const Text(
          'Delete Credential',
          style: TextStyle(color: Shared.error, fontSize: 15),
        ),
      ),
    );
  }
}
