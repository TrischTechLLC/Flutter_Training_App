// lib/language_selection_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_3/generated/app_localizations.dart';

class LanguageSelectionPage extends StatelessWidget {
  final Function(Locale) setLocale;

  const LanguageSelectionPage({super.key, required this.setLocale});

  // Updated language list with Gujarati added
  static const languages = [
    {'name': 'English', 'code': 'en'},
    {'name': 'हिन्दी', 'code': 'hi'},
    {'name': 'తెలుగు', 'code': 'te'},
    {'name': 'मराठी', 'code': 'mr'},
    {'name': 'தமிழ்', 'code': 'ta'},
    {'name': 'മലയാളം', 'code': 'ml'},
    {'name': 'ಕನ್ನಡ', 'code': 'kn'},
    {'name': 'বাংলা', 'code': 'bn'},
    {'name': 'অসমীয়া', 'code': 'as'},
    {'name': 'ગુજરાતી', 'code': 'gu'}, // Gujarati Added
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLanguage),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: languages.length,
        itemBuilder: (context, i) {
          final lang = languages[i];
          final langName = lang['name'] as String;
          final langCode = lang['code'] as String;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.language, color: Colors.white),
              ),
              title: Text(
                langName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // This will change the entire app to selected language (including Gujarati)
                setLocale(Locale(langCode));
                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }
}