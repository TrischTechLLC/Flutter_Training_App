import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'welcome_page.dart';
import 'package:flutter_application_3/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TrackingApp());
}

class TrackingApp extends StatefulWidget {
  const TrackingApp({super.key});

  @override
  State<TrackingApp> createState() => _TrackingAppState();
}

class _TrackingAppState extends State<TrackingApp> {
  Locale _locale = const Locale('en');

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driver Tracking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), Locale('hi'), Locale('te'), Locale('mr'),
        Locale('ta'), Locale('ml'), Locale('kn'), Locale('bn'), Locale('as'),
      ],
      home: WelcomePage(setLocale: setLocale),
    );
  }
}