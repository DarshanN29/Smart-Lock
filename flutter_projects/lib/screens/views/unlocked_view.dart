// lib/screens/views/unlocked_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UnlockedView extends StatelessWidget {
  final String? qrPayload;
  final VoidCallback onRegenerate;
  
  const UnlockedView({
    required this.qrPayload,
    required this.onRegenerate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
          // ... (Rest of the text widgets)
          const SizedBox(height: 18),

          // QR output (if ready)
          if (qrPayload != null) ...[
            QrImageView(
              data: qrPayload!,
              version: QrVersions.auto,
              size: 260.0,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerate QR'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                // copy to clipboard for convenience
                await Clipboard.setData(ClipboardData(text: qrPayload!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('QR payload copied to clipboard')));
                }
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