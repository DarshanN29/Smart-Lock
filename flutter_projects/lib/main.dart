import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:local_auth/local_auth.dart';  // ← ADDED
import 'package:cryptography/cryptography.dart';
import 'dart:convert';
import 'dart:math';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:async';

void main() {
  runApp(const SmartLockApp());
}

class SmartLockApp extends StatelessWidget {
  const SmartLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SmartLockHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SmartLockHome extends StatefulWidget {
  const SmartLockHome({super.key});

  @override
  State<SmartLockHome> createState() => _SmartLockHomeState();
}

class _SmartLockHomeState extends State<SmartLockHome> {
  final String targetDeviceName = "DID-LOCK"; // ESP32 BLE NAME

  BluetoothDevice? _device;
  bool _connected = false;
  bool _authenticated = false; // ← ADDED

  // Ed25519 keypair (kept in-memory for demo). In a real app you should
  // persist the private key in secure storage and rotate appropriately.
  SimpleKeyPair? _edKeyPair;
  String? _qrPayload; // JSON string to encode into the QR (vc + nonce + signature)

  final LocalAuthentication auth = LocalAuthentication(); // ← ADDED

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  @override
  void initState() {
    super.initState();
    startScan();
  }

  // ---------------------------------------------------------
  // Start BLE Scan
  // ---------------------------------------------------------
  void startScan() async {
    print("🔍 Scanning for SmartLock...");

    await FlutterBluePlus.stopScan();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        print("Found: ${r.device.name} → ${r.device.id}");

        if (r.device.name == targetDeviceName) {
          print("🎯 TARGET FOUND → ${r.device.id}");
          FlutterBluePlus.stopScan();
          connectToDevice(r.device);
          break;
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  // ---------------------------------------------------------
  // Connect To ESP32
  // ---------------------------------------------------------
  Future<void> connectToDevice(BluetoothDevice d) async {
    print("⏳ Connecting to ${d.id} ...");

    try {
      await d.connect(
        license: License.free,
        timeout: const Duration(seconds: 8),
      );
      print("✅ Connected Successfully");

      _connSub = d.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          print("⚠️ DEVICE DISCONNECTED");
          setState(() {
            _connected = false;
            _authenticated = false; // lock again on disconnect
          });

          Future.delayed(const Duration(seconds: 2), () {
            print("🔁 Reconnecting...");
            startScan();
          });
        }
      });

      setState(() {
        _device = d;
        _connected = true;
      });
    } catch (e) {
      print("❌ Connection Failed: $e");

      Future.delayed(const Duration(seconds: 3), () => startScan());
    }
  }

  @override
  void dispose() {
    print("🧹 Disposing Resources...");
    _scanSub?.cancel();
    _connSub?.cancel();
    _device?.disconnect();
    super.dispose();
  }

  // ---------------------------------------------------------
  // BIOMETRIC AUTH (Only added function)
  // ---------------------------------------------------------
  Future<void> authenticate() async {
    try {
      bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Tap fingerprint to unlock',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (didAuthenticate) {
        setState(() => _authenticated = true);

        // Generate VC + nonce + signature and produce QR payload
        await _ensureKeyPair();
        await _createAndSetQrPayload();
      }
    } catch (e) {
      print("Auth Error: $e");
    }
  }

  // Ensure we have an Ed25519 keypair in memory
  Future<void> _ensureKeyPair() async {
    if (_edKeyPair == null) {
      final algorithm = Ed25519();
      _edKeyPair = await algorithm.newKeyPair();
    }
  }

  // Build a small example Verifiable Credential (VC), create a nonce,
  // sign (vc + '.' + nonce) with Ed25519 and set _qrPayload as a JSON
  // string containing vc, nonce, signature and publicKey (base64url).
Future<void> _createAndSetQrPayload() async {
  if (_edKeyPair == null) await _ensureKeyPair();

  // Minimal VC value
  final vc = "access";

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

  setState(() => _qrPayload = jsonEncode(payload));
}


  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------
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
          // ← SAME UI, JUST LOCK BASED ON AUTH
          Padding(
            padding: const EdgeInsets.only(right: 18.0),
            child: Icon(
              _connected && _authenticated
                  ? Icons.lock_open_rounded
                  : Icons.lock_rounded,
              color: _connected && _authenticated
                  ? Colors.blueAccent
                  : Colors.redAccent,
              size: 30,
            ),
          )
        ],
      ),

      // ********************************************
      // DO NOT AUTO UNLOCK — NOW NEEDS FINGERPRINT
      // ********************************************
      body: Center(
        child: !_connected
            ? buildLockedView()
            : !_authenticated
                ? buildTapToUnlockButton()
                : buildUnlockedView(),
      ),
    );
  }

  // ---------------------------------------------------------
  // ADDED "Tap to Unlock" Button
  // ---------------------------------------------------------
  Widget buildTapToUnlockButton() {
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
          onPressed: authenticate,
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

  // ---------------------------------------------------------
  // LOCKED VIEW
  // ---------------------------------------------------------
  Widget buildLockedView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.lock_rounded, size: 120, color: Colors.redAccent),
        SizedBox(height: 25),
        Text(
          "LOCKED",
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),
        Text(
          "SmartLock Not Found!",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Ensure SmartLock is powered & nearby.",
          style: TextStyle(
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // UNLOCKED VIEW
  // ---------------------------------------------------------
  Widget buildUnlockedView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_open_rounded, size: 120, color: Colors.blueAccent),
          const SizedBox(height: 25),
          const Text(
            "UNLOCKED",
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "SmartLock Connected!",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Secure BLE Link Established.",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 18),

          // QR output (if ready)
          if (_qrPayload != null) ...[
            QrImageView(
              data: _qrPayload!,
              version: QrVersions.auto,
              size: 260.0,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async => await _createAndSetQrPayload(),
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerate QR'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                // copy to clipboard for convenience
                await Clipboard.setData(ClipboardData(text: _qrPayload!));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR payload copied to clipboard')));
              },
              child: const Text('Copy QR JSON'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text('Generating credential...', style: TextStyle(fontSize: 16)),
          ],
        ],
      ),
    );
  }
}
