import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erguo/screens/worker/worker_timer_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerWaitingScreen extends StatefulWidget {
  final String workerCode;

  const WorkerWaitingScreen({super.key, required this.workerCode});

  @override
  _WorkerWaitingScreenState createState() => _WorkerWaitingScreenState();
}

class _WorkerWaitingScreenState extends State<WorkerWaitingScreen> {
  String? requestId; // Store request ID

  /// 🔹 **Get real-time worker status from Firestore**
  Stream<String?> getRequestStatusFromWorkerCode() async* {
    try {
      // 🔹 Step 1: Get the request document with this workerCode
      final requestSnap = await FirebaseFirestore.instance
          .collection('service_requests')
          .where('workerCode', isEqualTo: widget.workerCode)
          .limit(1)
          .get();

      if (requestSnap.docs.isEmpty) {
        yield "Request not found";
        return;
      }

      final requestDoc = requestSnap.docs.first;
      requestId = requestDoc.id;

      // 🔹 Step 2: Listen to the request's status in real-time
      yield* FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .snapshots()
          .map((snap) => snap.data()?['status'] as String?);
    } catch (e) {
      yield "error";
    }
  }

  Future<void> _launchClientLocation() async {
    if (requestId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('service_requests')
        .doc(requestId)
        .get();

    final locationString = doc.data()?['location']; // Format: "lat,long"
    if (locationString == null) return;

    final parts = locationString.split(',');
    if (parts.length != 2) return;

    final lat = parts[0];
    final lng = parts[1];

    final url =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch Maps")),
      );
    }
  }

  Widget _buildLocationButton() {
    if (requestId == null) return const SizedBox.shrink();

    return ElevatedButton.icon(
      onPressed: _launchClientLocation,
      icon: const Icon(Icons.location_on),
      label: const Text("Show Client Location"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFEDF6FF), // Light blue background
      body: Center(
        child: StreamBuilder<String?>(
          stream: getRequestStatusFromWorkerCode(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                !snapshot.hasData) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWaitingUI("Checking status..."),
                  const SizedBox(height: 30),
                  _buildLocationButton(), // 🔹 Button to view location
                ],
              );
            }

            final String status = snapshot.data ?? "waiting";

            if (status == "Final Proceed") {
              Future.delayed(Duration.zero, () async {
                if (requestId != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          WorkerTimerScreen(requestId: requestId!),
                    ),
                  );
                }
              });
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSuccessUI("approved! Redirecting..."),
                  const SizedBox(height: 30),
                  _buildLocationButton(),
                ],
              );
            } else if (status == "rejected") {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildErrorUI("rejected. Contact admin for details."),
                  const SizedBox(height: 30),
                  _buildLocationButton(),
                ],
              );
            } else if (status == "approved") {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildInfoUI(
                      "Request was approved. Waiting for admin verification."),
                  const SizedBox(height: 30),
                  _buildLocationButton(),
                ],
              );
            } else {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildErrorUI("Unexpected status. Please contact support."),
                  const SizedBox(height: 30),
                  _buildLocationButton(),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  /// 🔄 **Loading UI with Animated Loader**
  Widget _buildWaitingUI(String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.black),
        const SizedBox(height: 20),
        Text(
          text,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ],
    );
  }

  /// ✅ **Success UI (Green Tick)**
  Widget _buildSuccessUI(String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 20),
        Text(
          text,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ],
    );
  }

  /// ⚠️ **Error UI (Red Warning)**
  Widget _buildErrorUI(String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 20),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
        ),
      ],
    );
  }

  /// ℹ️ **Info UI (Clock Icon)**
  Widget _buildInfoUI(String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.access_time, color: Colors.black, size: 80),
        const SizedBox(height: 20),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ],
    );
  }
}
