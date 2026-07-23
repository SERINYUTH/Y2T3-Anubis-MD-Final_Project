import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/credential.dart';
import '../../models/category.dart';
import '../../repositories/credential_repository.dart';
import 'add_edit_screen.dart';
import 'detail_screen.dart';
import '../theme/shared.dart';
import '../theme/category_style.dart';
import '../widgets/primary_button.dart';

// This screen shows the list of saved credentials
class VaultScreen extends StatefulWidget {
  // The repository this screen reads credentials from
  final CredentialRepository credentialRepository;

  final encryptionService;

  // The AES key used for decryption, already derived at login
  final String aesKey;

  const VaultScreen({
    super.key,
    required this.credentialRepository,
    required this.encryptionService,
    required this.aesKey,
  });

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  // Keeps track of which category chip is currently selected
  CredentialCategory? selectedCategory;

  // True while credentials are being loaded from the repository
  bool isLoading = true;

  // Holds any error message if loading fails, shown on screen for debugging
  String? loadError;

  // Holds whatever text is currently typed into the search bar
  String searchQuery = '';

  // The full list of credentials, already decrypted, ready to display
  List<Map<String, dynamic>> decryptedCredentials = [];

  @override
  void initState() {
    super.initState();
    loadCredentials();
  }

  // Loads every credential from the repository, then decrypts each one
  Future<void> loadCredentials() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      List<Credential> credentials = await widget.credentialRepository
          .getAllCredentials();

      List<Map<String, dynamic>> results = [];

      for (var credential in credentials) {
        String decryptedJsonString = await widget.encryptionService.decrypt(
          credential.encryptedData,
          widget.aesKey,
        );

        CredentialData data = CredentialData.fromJsonString(
          decryptedJsonString,
        );

        results.add({
          'credential': credential,
          'title': data.title,
          'username': data.username,
        });
      }

      setState(() {
        decryptedCredentials = results;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        loadError = e.toString();
        isLoading = false;
      });
    }
  }

  // This function returns only the credentials that match both the
  // selected category and the search text typed in the search bar
  List<Map<String, dynamic>> getFilteredCredentials() {
    List<Map<String, dynamic>> filtered = [];

    for (var entry in decryptedCredentials) {
      Credential credential = entry['credential'];
      String title = entry['title'];
      String username = entry['username'];

      bool matchesCategory =
          selectedCategory == null || credential.category == selectedCategory;

      bool matchesSearch =
          searchQuery.isEmpty ||
          title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          username.toLowerCase().contains(searchQuery.toLowerCase());

      if (matchesCategory && matchesSearch) {
        filtered.add(entry);
      }
    }

    return filtered;
  }

  // Turns "work" into "Work" for display on the category chips
  String capitalize(String text) {
    String firstLetter = text[0].toUpperCase();
    String restOfText = text.substring(1);
    return firstLetter + restOfText;
  }

  // Opens the Add/Edit screen in Add mode, then reloads the list on return
  Future<void> openAddScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditScreen(
          credentialRepository: widget.credentialRepository,
          encryptionService: widget.encryptionService,
          aesKey: widget.aesKey,
        ),
      ),
    );

    loadCredentials();
  }

  // Opens the Detail screen for one credential, then reloads the list on return
  Future<void> openDetailScreen(Credential credential) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(
          credential: credential,
          credentialRepository: widget.credentialRepository,
          encryptionService: widget.encryptionService,
          aesKey: widget.aesKey,
        ),
      ),
    );

    loadCredentials();
  }

  // Decrypts just the password for one credential, then copies it
  // Password is not kept decrypted in decryptedCredentials, so it gets
  // decrypted again here, only for the moment it is copied
  Future<void> copyPassword(Credential credential) async {
    String decryptedJsonString = await widget.encryptionService.decrypt(
      credential.encryptedData,
      widget.aesKey,
    );

    CredentialData data = CredentialData.fromJsonString(decryptedJsonString);

    await Clipboard.setData(ClipboardData(text: data.password));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> credentialsToShow = getFilteredCredentials();

    return Scaffold(
      backgroundColor: Shared.background,
      floatingActionButton: FloatingActionButton(
        onPressed: openAddScreen,
        backgroundColor: Shared.gold,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: "My Vault" title + settings gear icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Vault',
                    style: TextStyle(
                      color: Shared.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Will navigate to the Settings screen later
                    },
                    icon: const Icon(
                      Icons.settings,
                      color: Shared.gold,
                      size: 28,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Shared.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Shared.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Shared.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        style: const TextStyle(color: Shared.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Search credentials',
                          hintStyle: TextStyle(color: Shared.textSecondary),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Category filter chips, scrollable left to right
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: buildCategoryChips(),
                ),
              ),

              const SizedBox(height: 16),

              // Main content: loading spinner, empty state, or the list
              Expanded(child: buildMainContent(credentialsToShow)),
            ],
          ),
        ),
      ),
    );
  }

  // Decides what to show below the chips
  Widget buildMainContent(List<Map<String, dynamic>> credentialsToShow) {
    if (isLoading == true) {
      return const Center(child: CircularProgressIndicator(color: Shared.gold));
    }

    if (loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load vault\n$loadError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Shared.error),
          ),
        ),
      );
    }

    if (credentialsToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your vault is empty',
              style: TextStyle(color: Shared.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Add your first credential',
              onPressed: openAddScreen,
            ),
          ],
        ),
      );
    }

    return ListView(children: buildCredentialCards(credentialsToShow));
  }

  // Builds the list of category chip widgets
  List<Widget> buildCategoryChips() {
    List<Widget> chips = [];

    chips.add(buildOneChip(label: 'All', category: null));

    for (var category in CredentialCategory.values) {
      chips.add(
        buildOneChip(label: capitalize(category.name), category: category),
      );
    }

    return chips;
  }

  // "All" chip, which clears the filter when tapped
  Widget buildOneChip({
    required String label,
    required CredentialCategory? category,
  }) {
    bool isSelected = category == selectedCategory;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedCategory = category;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Shared.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? Shared.gold : Shared.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Shared.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // Builds the list of credential card widgets
  List<Widget> buildCredentialCards(List<Map<String, dynamic>> entries) {
    List<Widget> cards = [];

    for (var entry in entries) {
      Credential credential = entry['credential'];
      String title = entry['title'];
      String username = entry['username'];

      Widget card = GestureDetector(
        onTap: () {
          openDetailScreen(credential);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Shared.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Shared.border),
          ),
          child: Row(
            children: [
              // Icon square
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: getCategoryColor(credential.category),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  getCategoryIcon(credential.category),
                  color: Colors.white,
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              // Title + username
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Shared.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      username,
                      style: const TextStyle(
                        color: Shared.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Copy icon button, copies the password without opening detail
              IconButton(
                onPressed: () {
                  copyPassword(credential);
                },
                icon: const Icon(
                  Icons.copy_outlined,
                  color: Shared.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );

      cards.add(card);
    }

    return cards;
  }
}
