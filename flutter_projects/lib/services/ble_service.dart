// lib/services/ble_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Enum to represent connection status
enum ConnectionStatus { searching, connected, disconnected }

class BleService {
  final String targetDeviceName;
  
  // Callback function to be executed when connected
  final VoidCallback onConnectedShowNotification; 

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  // Stream to report current status back to the UI
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  
  BluetoothDevice? currentDevice;

  // Constructor now requires the notification callback
  BleService(this.targetDeviceName, {required this.onConnectedShowNotification});

  // Placeholder for the notification logic
  void _triggerNotification() {
    debugPrint("🔔 NOTIFICATION TRIGGERED: TAP TO UNLOCK!");
    onConnectedShowNotification();
  }

  // ---------------------------------------------------------
  // Start BLE Scan
  // ---------------------------------------------------------
  void startScan() async {
    debugPrint("🔍 Scanning for $targetDeviceName...");
    _statusController.add(ConnectionStatus.searching);

    await FlutterBluePlus.stopScan();

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.name == targetDeviceName) {
          debugPrint("🎯 TARGET FOUND: ${r.device.id}");
          FlutterBluePlus.stopScan();
          connectToDevice(r.device);
          return; // Stop processing results once found
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  // ---------------------------------------------------------
  // Connect To Device
  // ---------------------------------------------------------
  Future<void> connectToDevice(BluetoothDevice d) async {
    debugPrint("⏳ Connecting to ${d.id} ...");
    
    try {
      await d.connect(
        license: License.free,
        timeout: const Duration(seconds: 8),
      );
      debugPrint("✅ Connected Successfully");
      currentDevice = d;
      _statusController.add(ConnectionStatus.connected);
      
      // 💡 NEW: Trigger the notification callback upon successful connection
      _triggerNotification(); 

      _connSub?.cancel();
      _connSub = d.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint("⚠️ DEVICE DISCONNECTED");
          _statusController.add(ConnectionStatus.disconnected);
          currentDevice = null;
          
          // Reconnection logic
          Future.delayed(const Duration(seconds: 2), () {
            debugPrint("🔁 Reconnecting...");
            startScan();
          });
        }
      });
    } catch (e) {
      debugPrint("❌ Connection Failed: $e");
      _statusController.add(ConnectionStatus.disconnected);
      Future.delayed(const Duration(seconds: 3), () => startScan());
    }
  }

  // ---------------------------------------------------------
  // Cleanup Resources
  // ---------------------------------------------------------
  void dispose() {
    debugPrint("🧹 Disposing BLE Resources...");
    _scanSub?.cancel();
    _connSub?.cancel();
    currentDevice?.disconnect();
    _statusController.close();
  }
}