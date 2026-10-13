import 'package:flutter/material.dart';
import 'chat_page.dart';

void main() {
  runApp(const LandingPage());
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anna AI Receptionist',
      home: const ChatPage(),
    );
  }
}