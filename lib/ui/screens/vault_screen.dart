import 'package:flutter/material.dart';
import '../../models/credential.dart';
import '../../models/category.dart';
import '../../repositories/credential_repository.dart';

// This screen shows the list of saved credentials
// Now uses the real CredentialRepository instead of mock data
class VaultScreen extends StatefulWidget {
  // The repository this screen reads credentials from
  final CredentialRepository credentialRepository;

  // The service that knows how to decrypt encryptedData back into
  // a readable CredentialData object
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
  // Null means "All" is selected (no filter applied)
  CredentialCategory? selectedCategory;

  // True while credentials are being loaded from the repository
  bool isLoading = true;

  // The full list of credentials, already decrypted, ready to display
  List<Map<String, dynamic>> decryptedCredentials = [];

  @override
  void initState() {
    super.initState();
    loadCredentials();
  }

  // Loads every credential from the repository, then decrypts each one
  // so the title and username can be shown on screen
  Future<void> loadCredentials() async {
    setState(() {
      isLoading = true;
    });

    List<Credential> credentials = await widget.credentialRepository
        .getAllCredentials();

    List<Map<String, dynamic>> results = [];

    for (var credential in credentials) {
      String decryptedJsonString = await widget.encryptionService.decrypt(
        credential.encryptedData,
        widget.aesKey,
      );

      CredentialData data = CredentialData.fromJsonString(decryptedJsonString);

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
  }

  // This function returns only the credentials that match the currently selected category
  // If selectedCategory is null, every credential is returned (the "All" case)
  List<Map<String, dynamic>> getFilteredCredentials() {
    if (selectedCategory == null) {
      return decryptedCredentials;
    }

    List<Map<String, dynamic>> filtered = [];
    for (var entry in decryptedCredentials) {
      Credential credential = entry['credential'];
      if (credential.category == selectedCategory) {
        filtered.add(entry);
      }
    }
    return filtered;
  }

  // Returns the icon that should be shown for a given category
  IconData getCategoryIcon(CredentialCategory category) {
    if (category == CredentialCategory.social) {
      return Icons.chat_bubble;
    }
    if (category == CredentialCategory.work) {
      return Icons.work;
    }
    if (category == CredentialCategory.finance) {
      return Icons.credit_card;
    }
    if (category == CredentialCategory.shopping) {
      return Icons.shopping_cart;
    }
    return Icons.folder;
  }

  // Returns the icon square background color for a given category
  Color getCategoryColor(CredentialCategory category) {
    if (category == CredentialCategory.social) {
      return const Color(0xFFB39DDB);
    }
    if (category == CredentialCategory.work) {
      return const Color(0xFF8B5A5A);
    }
    if (category == CredentialCategory.finance) {
      return const Color(0xFF4A90D9);
    }
    if (category == CredentialCategory.shopping) {
      return const Color(0xFFE8951C);
    }
    return const Color(0xFF616161);
  }

  // Turns "work" into "Work" for display on the category chips
  String capitalize(String text) {
    String firstLetter = text[0].toUpperCase();
    String restOfText = text.substring(1);
    return firstLetter + restOfText;
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> credentialsToShow = getFilteredCredentials();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
                      color: Color(0xFFF5F5F5),
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
                      color: Color(0xFFD4AF37),
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
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF9E9E9E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: const TextStyle(color: Color(0xFFF5F5F5)),
                        decoration: const InputDecoration(
                          hintText: 'Search credentials',
                          hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
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

  // Decides what to show below the chips: a loading spinner while
  // credentials are being fetched, an empty state message if there are
  // no credentials to show, or the actual list of credential cards
  Widget buildMainContent(List<Map<String, dynamic>> credentialsToShow) {
    if (isLoading == true) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      );
    }

    if (credentialsToShow.isEmpty) {
      return const Center(
        child: Text(
          'Your vault is empty',
          style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 16),
        ),
      );
    }

    return ListView(children: buildCredentialCards(credentialsToShow));
  }

  // Builds the list of category chip widgets
  // The first chip is always "All". The rest come from every value in
  // the CredentialCategory enum
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

  // Builds a single chip widget. If category is null, this is the
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
            color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFF2C2C2C),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : const Color(0xFFF5F5F5),
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

      Widget card = Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2C2C2C)),
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
                      color: Color(0xFFF5F5F5),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    username,
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Copy icon button
            IconButton(
              onPressed: () {
                // Will copy the password to the clipboard later (30 second auto-clear)
              },
              icon: const Icon(Icons.copy_outlined, color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
      );

      cards.add(card);
    }

    return cards;
  }
}
