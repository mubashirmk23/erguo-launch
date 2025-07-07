import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientTimerViewScreen extends StatefulWidget {
  final String requestId;

  const ClientTimerViewScreen({super.key, required this.requestId});

  @override
  State<ClientTimerViewScreen> createState() => _ClientTimerViewScreenState();
}

class _ClientTimerViewScreenState extends State<ClientTimerViewScreen> {
  int hours = 0;
  int minutes = 0;
  int seconds = 0;

  late DatabaseReference _timerRef;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _timerRef = FirebaseDatabase.instance.ref("timers/${widget.requestId}");
    _fetchTimerData(); // initial load
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _fetchTimerData();
    });
  }

  Future<void> _fetchTimerData() async {
    final snapshot = await _timerRef.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        hours = data['hours'] ?? 0;
        minutes = data['minutes'] ?? 0;
        seconds = data['seconds'] ?? 0;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _formatUnit(int unit) => unit.toString().padLeft(2, '0');

  // 🔹 Get phone number from any admin doc and call
  Future<void> _callAdmin() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('admins').limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        final phone = snapshot.docs.first.data()['phone number'];

        final Uri uri = Uri(
          scheme: 'tel',
          path: phone,
        );

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri,
              mode: LaunchMode.externalApplication); // 👈 IMPORTANT
        } else {
          _showSnackBar("Could not launch dialer.");
        }
      } else {
        _showSnackBar("No admin phone number found.");
      }
    } catch (e) {
      _showSnackBar("Error fetching number: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF6FF),
      appBar: AppBar(
        title: const Text("Live Work Timer",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: Colors.black),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ⏱ Cool Styled Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Text(
                "${_formatUnit(hours)} : ${_formatUnit(minutes)} : ${_formatUnit(seconds)}",
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Auto-updates every 5 minutes",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 40),

            // 🔘 Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _callAdmin,
                    icon: const Icon(Icons.phone),
                    label: const Text("Call Engineer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
