// lib/screens/views/tap_to_unlock_view.dart

import 'package:flutter/material.dart';

class TapToUnlockView extends StatelessWidget {
  final VoidCallback onTap;
  const TapToUnlockView({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_rounded, size: 120, color: Colors.orange),
        const SizedBox(height: 25),
        const Text(
          "SmartLock Connected!",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 25),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          ),
          child: const Text(
            "TAP TO UNLOCK",
            style: TextStyle(fontSize: 22, color: Colors.white),
          ),
        ),
      ],
    );
  }
}