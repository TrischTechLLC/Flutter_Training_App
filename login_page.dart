// lib/login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_page.dart';
import 'welcome_page.dart';
import 'package:flutter_application_3/generated/app_localizations.dart';

class LoginPage extends StatefulWidget {
  final Function(Locale) setLocale;

  const LoginPage({super.key, required this.setLocale});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _truckIdController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _truckIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    final truckId = _truckIdController.text.trim();
    final phone = _phoneController.text.trim();

    if (truckId.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.enterDetails)),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.code} - ${e.message}')),
          );
          setState(() => _isSending = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isSending = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpPage(
                truckId: truckId,
                phone: phone,
                verificationId: verificationId,
                setLocale: widget.setLocale,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending OTP: $e')),
      );
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.3),
        title: Text(AppLocalizations.of(context)!.driverLogin),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => WelcomePage(setLocale: widget.setLocale),
              ),
            );
          },
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset("assets/login_bg.jpeg", fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.3)),
          Center(
            child: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Card(
                  elevation: 8,
                  color: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset("assets/logo.png", height: 100),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _truckIdController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.enterTruckId,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.enterPhoneNumber,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSending ? null : _sendOtp,
                            child: _isSending
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(AppLocalizations.of(context)!.sendOtp),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}