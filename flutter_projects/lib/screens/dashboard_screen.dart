// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:smartlock_app/screens/lock_home_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: const Color(0xFFF2F6F4),
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ------------------------------------
          // Profile Section
          // ------------------------------------
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.person, size: 40, color: Colors.blueGrey),
              title: const Text("User Profile"),
              subtitle: const Text("Manage your account and settings"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Future profile management screen
              },
            ),
          ),
          const Divider(),
          // ------------------------------------
          // Locks Section (Main Feature)
          // ------------------------------------
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Your Smart Locks",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.lock_rounded, size: 40, color: Colors.blueAccent),
              title: const Text("DID-LOCK (Main Entrance)"),
              subtitle: const Text("Tap to view status and unlock"),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () {
                // Navigate to the existing lock interaction screen
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LockHomeScreen()),
                );
              },
            ),
          ),
          // You can add more locks here later
        ],
      ),
    );
  }
}