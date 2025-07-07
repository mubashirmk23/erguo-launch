import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ThankYouScreen extends StatefulWidget {
  final String requestId;
  final int totalPrice;

  const ThankYouScreen(
      {super.key, required this.requestId, required this.totalPrice});

  @override
  _ThankYouScreenState createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen> {
  String requestStatus = "bill ready"; // Default status

  @override
  void initState() {
    super.initState();
    _updateWorkerHistories(); // 🔹 Update workers' work history first
    _listenToRequestStatus(); // 🔹 Then start listening for status changes
  }

  Future<void> _updateWorkerHistories() async {
    try {
      final workersSnapshot = await FirebaseFirestore.instance
          .collection('workers')
          .where('workerCode', isEqualTo: widget.requestId)
          .get();

      for (final doc in workersSnapshot.docs) {
        final workerRef = doc.reference;
        await workerRef.update({
          'workHistory': FieldValue.arrayUnion([
            {
              'requestId': widget.requestId,
              'timestamp': FieldValue.serverTimestamp(),
            }
          ]),
        });
      }
    } catch (e) {
      print("Failed to update work history: $e");
    }
  }

  void _listenToRequestStatus() {
    FirebaseFirestore.instance
        .collection('service_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final newStatus = snapshot.get('status') ?? "bill ready";

        if (mounted) {
          setState(() {
            requestStatus = newStatus;
          });
        }

        // 🔥 When bill is paid, delete workerCode from workers
        if (newStatus == "bill paid") {
          try {
            final workersSnapshot = await FirebaseFirestore.instance
                .collection('workers')
                .where('workerCode', isEqualTo: widget.requestId)
                .get();

            for (final doc in workersSnapshot.docs) {
              await doc.reference.update({
                'workerCode': FieldValue.delete(),
              });
            }
          } catch (e) {
            print("Failed to delete workerCode from workers: $e");
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isBillPaid = requestStatus == "bill paid";

    return WillPopScope(
      onWillPop: () async => isBillPaid, // Prevent back if bill isn't paid
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated Checkmark Icon (Only when bill is paid)
                if (isBillPaid)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: const Icon(Icons.check_circle,
                        size: 100, color: Colors.green),
                  )
                else
                  const CircularProgressIndicator(
                      color: Colors.black), // Loading icon for waiting state

                const SizedBox(height: 30),

                // Status Text
                Text(
                  isBillPaid ? "Thank You!" : "Waiting for Payment...",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isBillPaid
                      ? "Your bill has been successfully paid."
                      : "Please wait while the client processes the payment.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 20),

                // Bill Amount Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Total Amount: ₹${widget.totalPrice}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Back to Home Button (Only visible if bill is paid)
                if (isBillPaid)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back to previous screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      "Back to Home",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
