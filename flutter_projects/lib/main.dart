// lib/main.dart (Updated)

import 'package:flutter/material.dart';
import 'package:smartlock_app/screens/splash_screen.dart'; // Import the new splash screen

void main() {
  runApp(const SmartLockApp());
}

class SmartLockApp extends StatelessWidget {
  const SmartLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      // 💡 Start with the splash screen
      home: SplashScreen(), 
      debugShowCheckedModeBanner: false,
    );
  }
}