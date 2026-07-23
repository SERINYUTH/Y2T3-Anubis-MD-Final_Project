import 'package:flutter/material.dart';
import '../../models/category.dart';

// Turns a CredentialCategory into the icon and color shown for it
// Used by the vault screen and the detail screen, kept in one place
// so both always show the same thing for the same category
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

Color getCategoryColor(CredentialCategory category) {
  if (category == CredentialCategory.social) {
    return Colors.purpleAccent;
  }
  if (category == CredentialCategory.work) {
    return Colors.blueAccent;
  }
  if (category == CredentialCategory.finance) {
    return Colors.greenAccent;
  }
  if (category == CredentialCategory.shopping) {
    return Colors.orangeAccent;
  }
  return Colors.limeAccent;
}
