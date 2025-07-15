import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRCodeScreen extends StatelessWidget {
  const QRCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const qrUrl = "https://mubashirmk23.github.io/erguo-launch/";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Erguo App QR Code"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: qrUrl,
              version: QrVersions.auto,
              size: 250.0,
            ),
            const SizedBox(height: 20),
            const Text(
              "Scan to open or install app",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text("Copy QR Link"),
              onPressed: () {
                // Optional: Add Clipboard functionality if needed
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("URL: $qrUrl")),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
