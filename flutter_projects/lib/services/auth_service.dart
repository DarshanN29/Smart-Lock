// lib/services/auth_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();
  SimpleKeyPair? _edKeyPair;

  // Handles the biometric prompt
  Future<bool> authenticate() async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Tap fingerprint to unlock',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      return didAuthenticate;
    } catch (e) {
      debugPrint("Auth Error: $e");
      return false;
    }
  }

  // Ensures we have an Ed25519 keypair in memory (moved from _ensureKeyPair)
  Future<void> ensureKeyPair() async {
    if (_edKeyPair == null) {
      final algorithm = Ed25519();
      _edKeyPair = await algorithm.newKeyPair();
    }
  }

  // Generates and signs the QR payload (moved from _createAndSetQrPayload)
  Future<String> createQrPayload() async {
    await ensureKeyPair();

    // Minimal VC value
    const vc = "access";

    // Generate random nonce
    final rnd = Random.secure();
    final nonceBytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final nonce = base64UrlEncode(nonceBytes);

    // Message to sign
    final message = "$vc.$nonce";

    // Sign using Ed25519
    final algorithm = Ed25519();
    final signature = await algorithm.sign(
      utf8.encode(message),
      keyPair: _edKeyPair!,
    );

    final payload = {
      "vc": vc,
      "nonce": nonce,
      "signature": base64UrlEncode(signature.bytes),
    };

    return jsonEncode(payload);
  }
}