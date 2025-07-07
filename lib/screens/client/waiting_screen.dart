import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erguo/screens/client/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// State class for managing countdown and cancellation
class WaitingState {
  final int countdown;
  final bool canCancel;
  final bool requestCompleted;

  WaitingState({
    required this.countdown,
    required this.canCancel,
    required this.requestCompleted,
  });

  WaitingState copyWith(
      {int? countdown, bool? canCancel, bool? requestCompleted}) {
    return WaitingState(
      countdown: countdown ?? this.countdown,
      canCancel: canCancel ?? this.canCancel,
      requestCompleted: requestCompleted ?? this.requestCompleted,
    );
  }
}

// StateNotifier to manage countdown, cancellation, and request status checking
class WaitingNotifier extends StateNotifier<WaitingState> {
  final String requestId;
  Timer? timer;
  StreamSubscription<DocumentSnapshot>? requestListener;

  WaitingNotifier(this.requestId)
      : super(WaitingState(
            countdown: 900, canCancel: true, requestCompleted: false)) {
    _startTimer();
    _listenForApproval();
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdown > 0) {
        state = state.copyWith(countdown: state.countdown - 1);
      } else {
        state = state.copyWith(canCancel: false, requestCompleted: true);
        timer.cancel();
      }
    });
  }

  void _listenForApproval() {
    requestListener = FirebaseFirestore.instance
        .collection('service_requests')
        .doc(requestId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data()?['status'] == 'approved') {
        state = state.copyWith(requestCompleted: true);
      }
    });
  }

  Future<void> cancelRequest(BuildContext context) async {
    if (!state.canCancel) return;

    await FirebaseFirestore.instance
        .collection('service_requests')
        .doc(requestId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Service request canceled.")),
    );

    _navigateToHome(context);
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    requestListener?.cancel();
    super.dispose();
  }
}

// Riverpod provider
final waitingProvider =
    StateNotifierProvider.family<WaitingNotifier, WaitingState, String>(
  (ref, requestId) => WaitingNotifier(requestId),
);

// Main UI
class WaitingScreen extends ConsumerWidget {
  final String requestId;
  const WaitingScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(waitingProvider(requestId));
    final notifier = ref.read(waitingProvider(requestId).notifier);

    // If request is approved, navigate to Home and show snackbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.requestCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request has been approved.")),
        );
        notifier._navigateToHome(context);
      }
    });

    return WillPopScope(
      onWillPop: () async {
        notifier._navigateToHome(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEDF6FF), // Your Figma background color
        appBar: AppBar(
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(height: 1, thickness: 1, color: Colors.black),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => notifier._navigateToHome(context),
          ),
          title: const Text(
            "Waiting for Confirmation",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: "DM Sans",
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                "Processing Your Request",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: "DM Sans",
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Timer Countdown
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: state.countdown / 900,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation(Colors.black),
                    ),
                  ),
                  Text(
                    "${(state.countdown ~/ 60).toString().padLeft(2, '0')}:${(state.countdown % 60).toString().padLeft(2, '0')}",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      fontFamily: "DM Sans",
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Instruction Text
              Text(
                "Your request is being reviewed. You can cancel within 15 minutes.",
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: "DM Sans",
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.canCancel
                      ? () => notifier.cancelRequest(context)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        state.canCancel ? Colors.black : Colors.grey[500],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    state.canCancel
                        ? "Cancel Request"
                        : "Cancellation Unavailable",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: "DM Sans",
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
