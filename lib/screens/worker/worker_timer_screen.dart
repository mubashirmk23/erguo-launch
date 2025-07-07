import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'bill_screen.dart'; // Replace with actual billing screen import
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerTimerScreen extends StatefulWidget {
  final String requestId;

  const WorkerTimerScreen({super.key, required this.requestId});

  @override
  _WorkerTimerScreenState createState() => _WorkerTimerScreenState();
}

class _WorkerTimerScreenState extends State<WorkerTimerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int totalSeconds = 0;
  Timer? _timer;
  bool isRunning = false;
  DatabaseReference? _timerRef;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.primaryFocus?.unfocus(); // Hide keyboard

    _timerRef = FirebaseDatabase.instance.ref("timers/${widget.requestId}");

    // 🟡 Load previous totalSeconds if exists
    _timerRef!.once().then((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          totalSeconds = data['totalSeconds'] ?? 0;
        });
      }
    });
  }

  void _toggleTimer() {
    if (isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() async {
    if (_timer != null && _timer!.isActive) {
      return; // ✅ Prevent multiple timers from running
    }

    setState(() {
      isRunning = true;
    });

    // Check if the document exists before updating Firestore
    final docRef =
        _firestore.collection("service_requests").doc(widget.requestId);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      await docRef.update({
        "status": "work started",
      });
    } else {
      debugPrint("Error: Request document does not exist in Firestore.");
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        totalSeconds++;
      });

      // Update Firebase every 5 minutes
      if (totalSeconds % (5 * 60) == 0) {
        _updateTimerInFirebase();
      }
    });
  }

  void _pauseTimer() {
    if (_timer == null || !_timer!.isActive) {
      return; // ✅ Prevent redundant pauses
    }
    setState(() {
      isRunning = false;
    });
    _timer?.cancel(); // ✅ Stops the timer properly
    _timer = null; // ✅ Reset the timer reference
    _updateTimerInFirebase(); // Update Firebase when paused
  }

  void _confirmEndTimer() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm End Work"),
          content: const Text("Are you sure you want to end the work?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _endTimer(); // Proceed to end the timer
              },
              child: const Text("Yes, End"),
            ),
          ],
        );
      },
    );
  }

  void _endTimer() async {
    _pauseTimer();
    _updateTimerInFirebase(); // Final update to Realtime DB

    final docRef =
        _firestore.collection("service_requests").doc(widget.requestId);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      int hours = totalSeconds ~/ 3600;
      int minutes = (totalSeconds % 3600) ~/ 60;
      int seconds = totalSeconds % 60;

      await docRef.update({
        "status": "work ended",
        "workDuration": {
          "totalSeconds": totalSeconds,
          "hours": hours,
          "minutes": minutes,
          "seconds": seconds,
          "endedAt": FieldValue.serverTimestamp(),
        }
      });

      // Navigate to billing screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BillScreen(
            totalSeconds: totalSeconds,
            requestId: widget.requestId,
          ),
        ),
      );
    } else {
      debugPrint("Error: Request document does not exist in Firestore.");
    }
  }

  void _updateTimerInFirebase() {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    _timerRef?.set({
      "totalSeconds": totalSeconds,
      "hours": hours,
      "minutes": minutes,
      "seconds": seconds,
      "lastUpdated": DateTime.now().toIso8601String(),
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Work Timer",
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🕒 Digital Timer Display
            Text(
              "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
              style: const TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),

            // 🟢 Start/Pause Button
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: _toggleTimer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRunning ? Colors.red : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  isRunning ? "Pause" : "Start",
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🛑 End Button
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed:
                    _confirmEndTimer, // 🔹 Call confirmation dialog first
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "End Work",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
