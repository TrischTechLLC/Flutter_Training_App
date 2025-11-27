// lib/welcome_page.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'options_page.dart';
import 'login_page.dart';           // ← Added back
import 'language_selection_page.dart';
import 'package:flutter_application_3/generated/app_localizations.dart';

class WelcomePage extends StatefulWidget {
  final Function(Locale) setLocale;
  const WelcomePage({super.key, required this.setLocale});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isDarkMode = true;
  final GlobalKey _descKey = GlobalKey();
  final GlobalKey _techKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _instructionsKey = GlobalKey();
  final GlobalKey _appPreviewKey = GlobalKey();
  int _currentIndex = 0;

  void _scrollToSection(GlobalKey key) {
    Navigator.pop(context);
    Scrollable.ensureVisible(key.currentContext!,
        duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
  }

  Widget buildCard(GlobalKey key, String title, Widget content) {
    return Card(
      key: key,
      color: _isDarkMode ? Colors.grey[850] : Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 12),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        height: key == _appPreviewKey ? 650 : 350,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black)),
            const SizedBox(height: 12),
            Expanded(
                child: DefaultTextStyle(
                    style: TextStyle(
                        fontSize: 16,
                        color: _isDarkMode ? Colors.white70 : Colors.black87),
                    child: content)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final backgroundColor = _isDarkMode ? Colors.grey[900] : Colors.grey[100];

    final List<String> appPreviewImages = [
      'assets/main_app.png',
      'assets/language_selection.png',
      'assets/tracking.png',
      'assets/options.png',
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        leading: Builder(
            builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer())),
        title: Text(l10n.locationTrackingApp,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.white),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: _isDarkMode ? Colors.grey[850] : Colors.white,
          child: ListView(padding: EdgeInsets.zero, children: [
            DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue[800]),
                child: Text(l10n.gpsTrackingAppMenu,
                    style: const TextStyle(color: Colors.white, fontSize: 20))),
            ListTile(title: Text(l10n.appDescription), onTap: () => _scrollToSection(_descKey)),
            ListTile(title: Text(l10n.techStack), onTap: () => _scrollToSection(_techKey)),
            ListTile(title: Text(l10n.features), onTap: () => _scrollToSection(_featuresKey)),
            ListTile(title: Text(l10n.instructions), onTap: () => _scrollToSection(_instructionsKey)),
            ListTile(title: const Text('App Preview'), onTap: () => _scrollToSection(_appPreviewKey)),
            ListTile(
                title: Text(l10n.languages),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LanguageSelectionPage(setLocale: widget.setLocale)));
                }),
          ]),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(children: [
          Text(l10n.welcomeToLocationTrackingApp,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.location_on,
                size: 80, color: _isDarkMode ? Colors.blue[300] : Colors.blue[700]),
          ),
          const SizedBox(height: 30),
          buildCard(_descKey, l10n.appDescriptionCardTitle, Text(l10n.appDescriptionText)),
          buildCard(_techKey, l10n.techStackCardTitle, Text(l10n.techStackText)),
          buildCard(_featuresKey, l10n.featuresCardTitle, Text(l10n.featuresText)),
          buildCard(_instructionsKey, l10n.instructionsCardTitle, Text(l10n.instructionsText)),
          buildCard(
            _appPreviewKey,
            'App Preview',
            Column(children: [
              CarouselSlider(
                options: CarouselOptions(
                    height: 500,
                    initialPage: _currentIndex,
                    onPageChanged: (i, _) => setState(() => _currentIndex = i),
                    enlargeCenterPage: true,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 4),
                    viewportFraction: 0.85),
                items: appPreviewImages
                    .map((path) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover))))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.blue, size: 20),
                    onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null),
                IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 20),
                    onPressed: _currentIndex < appPreviewImages.length - 1
                        ? () => setState(() => _currentIndex++)
                        : null),
              ])
            ]),
          ),
          const SizedBox(height: 40),

          // TWO BUTTONS: Login + Direct Enter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage(setLocale: widget.setLocale)),
                  );
                },
                child: Text("Login", style: const TextStyle(fontSize: 18, color: Colors.white)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OptionsPage(setLocale: widget.setLocale)),
                  );
                },
                child: Text("Enter App", style: const TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}