// lib/screens/lock_home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smartlock_app/services/auth_service.dart';
import 'package:smartlock_app/services/ble_service.dart';
import 'package:smartlock_app/screens/views/locked_view.dart';
import 'package:smartlock_app/screens/views/tap_to_unlock_view.dart';
import 'package:smartlock_app/screens/views/unlocked_view.dart';

class LockHomeScreen extends StatefulWidget {
  const LockHomeScreen({super.key});

  @override
  State<LockHomeScreen> createState() => _LockHomeScreenState();
}

class _LockHomeScreenState extends State<LockHomeScreen> {
  // Services
  final AuthService _authService = AuthService();
  
  // 💡 NEW: Placeholder function for the notification
  void _handleNotificationTrigger() {
    // This is where you would call your flutter_local_notifications code.
    // Since we don't have the package installed, we use a SnackBar.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🔔 NOTIFICATION: Tap to Unlock!"),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
  
  // 💡 NEW: Initialize BleService, passing the notification callback
  late final BleService _bleService = BleService(
    "DID-LOCK",
    onConnectedShowNotification: _handleNotificationTrigger,
  );
  

  // State variables
  bool _connected = false;
  bool _authenticated = false;
  String? _qrPayload;

  StreamSubscription<ConnectionStatus>? _bleStatusSub;

  @override
  void initState() {
    super.initState();
    // Subscribe to the BLE status stream
    _bleStatusSub = _bleService.statusStream.listen((status) {
      setState(() {
        _connected = status == ConnectionStatus.connected;
        // If disconnected, reset the authentication state
        if (!_connected) {
          _authenticated = false;
          _qrPayload = null;
        }
      });
    });

    _bleService.startScan();
  }

  // Authentication logic
  Future<void> handleAuthentication() async {
    final didAuthenticate = await _authService.authenticate();

    if (didAuthenticate) {
      final payload = await _authService.createQrPayload();
      setState(() {
        _authenticated = true;
        _qrPayload = payload;
      });
    }
  }
  
  // QR Regeneration logic
  Future<void> regenerateQr() async {
    final payload = await _authService.createQrPayload();
    setState(() => _qrPayload = payload);
  }

  // Dispose of resources
  @override
  void dispose() {
    debugPrint("🧹 Disposing LockHomeScreen Resources...");
    _bleStatusSub?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  // Simplified build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F6F4),
        elevation: 0,
        title: const Text(
          "SmartLock",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18.0),
            child: Icon(
              _connected && _authenticated ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: _connected && _authenticated ? Colors.blueAccent : Colors.redAccent,
              size: 30,
            ),
          )
        ],
      ),
      body: Center(
        child: !_connected
            ? const LockedView() // Extracted View
            : !_authenticated
                ? TapToUnlockView(onTap: handleAuthentication) // Extracted View
                : UnlockedView(
                    qrPayload: _qrPayload,
                    onRegenerate: regenerateQr,
                  ), // Extracted View
      ),
    );
  }
}