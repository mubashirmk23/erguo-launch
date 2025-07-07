import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erguo/screens/worker/bill_screen.dart';
import 'package:erguo/screens/worker/worker_timer_screen.dart';
import 'package:erguo/screens/worker/worker_waiting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 🔹 Worker Login State Management (Riverpod)
class WorkerLoginNotifier extends StateNotifier<bool> {
  WorkerLoginNotifier() : super(false);

  Future<Map<String, String>?> loginWorker(String enteredCode) async {
    if (enteredCode.isEmpty || enteredCode.length < 6) {
      return {"error": "Enter full worker code."};
    }

    state = true;

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('service_requests')
          .where('workerCode', isEqualTo: enteredCode)
          .where('status', whereIn: [
            'approved',
            'Workers ready to work',
            'Final Proceed',
            'work started',
            'work ended',
          ])
          .limit(1)
          .get();

      state = false;

      if (querySnapshot.docs.isEmpty) {
        return {"error": "Invalid code or request not available."};
      }

      final doc = querySnapshot.docs.first;
      return {
        "requestId": doc.id,
        "status": doc['status'],
        "workerCode": enteredCode
      };
    } catch (e) {
      state = false;
      return {"error": "Error: $e"};
    }
  }
}

final workerLoginProvider =
    StateNotifierProvider<WorkerLoginNotifier, bool>((ref) {
  return WorkerLoginNotifier();
});

/// 🔹 Worker Login Screen (OTP-Style Input)
class WorkerLoginScreen extends ConsumerStatefulWidget {
  const WorkerLoginScreen({super.key});

  @override
  _WorkerLoginScreenState createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends ConsumerState<WorkerLoginScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  void _onCodeEntered() async {
    String enteredCode = _controllers.map((c) => c.text).join();
    if (enteredCode.length < 6) return;

    final result =
        await ref.read(workerLoginProvider.notifier).loginWorker(enteredCode);

    if (result == null || result.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?["error"] ?? "Login failed.")));
      return;
    }

    final requestId = result["requestId"]!;
    final status = result["status"]!;
    final workerCode = result["workerCode"]!;

    // Update worker status to 'joined'
    final workerSnap = await FirebaseFirestore.instance
        .collection('workers')
        .where('workerCode', isEqualTo: workerCode)
        .limit(1)
        .get();

    if (workerSnap.docs.isNotEmpty) {
      final workerId = workerSnap.docs.first.id;
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(workerId)
          .update({'status': 'joined'});
    }

    // Navigate based on request status
    if (status == 'work started') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkerTimerScreen(requestId: requestId),
        ),
      );
    } else if (status == 'work ended') {
      // 🔸 Fetch totalSeconds from workDuration in Firestore
      final doc = await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .get();

      final data = doc.data();
      int totalSeconds = 0;

      if (data != null &&
          data.containsKey('workDuration') &&
          data['workDuration'] is Map &&
          data['workDuration']['totalSeconds'] != null) {
        totalSeconds = data['workDuration']['totalSeconds'];
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BillScreen(requestId: requestId, totalSeconds: totalSeconds),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkerWaitingScreen(workerCode: workerCode),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(workerLoginProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Worker Login",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// 🔹 **Title**
            const Text(
              "Enter Worker Code",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            /// 🔹 **OTP-style Input Fields**
            RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: (RawKeyEvent event) {
                if (event is RawKeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace) {
                  for (int i = 0; i < 6; i++) {
                    if (_focusNodes[i].hasFocus &&
                        _controllers[i].text.isEmpty &&
                        i > 0) {
                      FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
                      break;
                    }
                  }
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        counterText: "",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          if (index < 5) {
                            FocusScope.of(context)
                                .requestFocus(_focusNodes[index + 1]);
                          } else {
                            _onCodeEntered();
                          }
                        }
                      },
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            /// 🔹 **Login Button or Loading Indicator**
            isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onCodeEntered,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Login",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}
