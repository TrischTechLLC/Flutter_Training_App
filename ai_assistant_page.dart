// lib/ai_assistant_page.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_3/generated/app_localizations.dart';
import 'dart:convert';

class VoiceAssistantScreen extends StatefulWidget {
  final Function(Locale) setLocale;

  const VoiceAssistantScreen({super.key, required this.setLocale});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isLoading = false;
  String _detectedLangCode = "en";

  // ⛔ API key must NOT be added here
  // 🔐 Secure API key (passed at runtime)
  static const apiKey = String.fromEnvironment("OPENAI_API_KEY");

  final Map<String, String> _appGuides = {
    'en':
        '''To use this app, first open the app introduction page, then scroll down to see the login button and click on it. Now the login page will be opened. Enter your truck ID and mobile number to login into the app. Then an OTP will be sent to your phone. Enter it in the app. Now your location will be sent to the owner. Have a great experience with the app. Thank you!''',
    'hi':
        '''इस ऐप का उपयोग करने के लिए, पहले ऐप का परिचय पृष्ठ खोलें, फिर नीचे स्क्रॉल करें लॉगिन बटन देखने के लिए और उस पर क्लिक करें। अब लॉगिन पेज खुल जाएगा। ऐप में लॉगिन करने के लिए अपना ट्रक आईडी और मोबाइल नंबर दर्ज करें। फिर आपके फोन पर एक ओटीपी भेजा जाएगा। उसे ऐप में दर्ज करें। अब आपकी लोकेशन मालिक को भेज दी जाएगी। ऐप के साथ बेहतरीन अनुभव प्राप्त करें। धन्यवाद!''',
    'te':
        '''ఈ యాప్ ను వాడటానికి, మొదట యాప్ పరిచయ పేజీ ని తెరవండి. తర్వాత కిందకు స్క్రోల్ చేసి లాగిన్ బటన్ ని చూడండి మరియు దాని మీద క్లిక్ చేయండి. ఇప్పుడు లాగిన్ పేజీ తెరవబడుతుంది. యాప్ లో లాగిన్ అవ్వడానికి మీ ట్రక్ ఐడి మరియు మొబైల్ నంబర్ ను రాయండి. తర్వాత మీ ఫోన్ కి ఓటీపీ వస్తుంది. దాన్ని యాప్ లో రాయండి. ఇప్పుడు మీ లొకేషన్ యజమాని కి పంపబడుతుంది. యాప్ తో మంచి అనుభవం పొందండి. ధన్యవాదాలు!'''
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _greetUser();
  }

  Future<void> _initSpeech() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
    } else {
      await _speak(AppLocalizations.of(context)!.microphonePermissionDenied);
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _setTtsLanguage(String langCode) async {
    if (langCode == "te") {
      await _flutterTts.setLanguage("te-IN");
      await _flutterTts.setSpeechRate(0.45);
    } else if (langCode == "hi") {
      await _flutterTts.setLanguage("hi-IN");
    } else {
      await _flutterTts.setLanguage("en-US");
    }
  }

  Future<void> _greetUser() async {
    await _speak(AppLocalizations.of(context)!.aiGreeting);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.speak(text);
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            _processInput(result.recognizedWords);
            setState(() => _isListening = false);
          }
        },
      );
    }
  }

  bool _isAppRelatedQuery(String query) {
    query = query.toLowerCase();
    return [
      'app', 'login', 'otp', 'truck', 'use', 'help', 'guide',
      'యాప్', 'లాగిన్', 'ఓటీపీ', 'ట్రక్',
      'ऐप', 'लॉगिन', 'ओटीपी', 'ट्रक'
    ].any((k) => query.contains(k));
  }

  Future<void> _processInput(String input) async {
    setState(() => _isLoading = true);

    // 1️⃣ Language detection
    final langResponse = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content': 'Detect language and return only "en", "hi", or "te".'
          },
          {'role': 'user', 'content': input}
        ]
      }),
    );

    if (langResponse.statusCode == 200) {
      _detectedLangCode =
          jsonDecode(langResponse.body)['choices'][0]['message']['content']
              .trim()
              .toLowerCase();
    }

    String reply;

    // 2️⃣ If app related → do not call API
    if (_isAppRelatedQuery(input)) {
      reply = _appGuides[_detectedLangCode] ?? _appGuides['en']!;
    } else {
      // 3️⃣ Normal AI queries
      final aiResponse = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'Reply in same language, in friendly female assistant tone.'
            },
            {'role': 'user', 'content': input}
          ]
        }),
      );

      reply = aiResponse.statusCode == 200
          ? jsonDecode(aiResponse.body)['choices'][0]['message']['content']
          : "Sorry, an error occurred. Please try again.";
    }

    setState(() => _isLoading = false);
    await _setTtsLanguage(_detectedLangCode);
    await _speak(reply);
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.aiAssistant,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        size: 120,
                        color: _isListening ? Colors.red : Colors.blue[800],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isListening
                            ? AppLocalizations.of(context)!.listening
                            : AppLocalizations.of(context)!.tapToSpeak,
                      ),
                    ],
                  ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                backgroundColor: _isListening ? Colors.red : Colors.blue[800],
                onPressed: _toggleListening,
                child: Icon(
                  _isListening ? Icons.mic_off : Icons.mic,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
