import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'request_details_screen.dart';

/// 🔹 **Riverpod Provider for Real-Time Requests**
final requestsProvider = StreamProvider((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('service_requests')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .snapshots();
});

/// 🔹 **RequestScreen Using Riverpod**
class RequestScreen extends ConsumerWidget {
  const RequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsStream = ref.watch(requestsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Your Requests",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: Colors.black),
        ),
      ),
      body: requestsStream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text("Error: $error")),
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return const Center(
              child: Text("No requests found.",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.docs.length,
            itemBuilder: (context, index) {
              final request = snapshot.docs[index];
              final requestId = request.id;
              final data = request.data() as Map<String, dynamic>;

              final status = data['status'] ?? 'pending';
              final timestamp = (data['createdAt'] as Timestamp).toDate();
              final createdTime = timestamp.millisecondsSinceEpoch;
              final currentTime = DateTime.now().millisecondsSinceEpoch;
              final elapsedTime =
                  (currentTime - createdTime) ~/ 1000; // Seconds
              final canCancel = elapsedTime < 900; // 15 min limit

              return GestureDetector(
                onTap: !canCancel
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  RequestDetailsScreen(requestId: requestId)),
                        );
                      }
                    : null,
                child: _buildRequestCard(context, requestId,
                    data['serviceName'], status, timestamp, canCancel, ref),
              );
            },
          );
        },
      ),
    );
  }

  /// 🔹 **UI Card for Each Request**
  Widget _buildRequestCard(
    BuildContext context,
    String requestId,
    String? serviceName,
    String status,
    DateTime createdAt,
    bool canCancel,
    WidgetRef ref,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 **Service Name**
            Text(
              serviceName ?? 'Unknown Service',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            /// 🔹 **Status Badge**
            Row(
              children: [
                _buildStatusBadge(status),
                const Spacer(),

                /// 🔹 **Created Date**
                Text(
                  "${createdAt.day}-${createdAt.month}-${createdAt.year} "
                  "${(createdAt.hour > 12 ? createdAt.hour - 12 : createdAt.hour == 0 ? 12 : createdAt.hour)}:"
                  "${createdAt.minute.toString().padLeft(2, '0')} "
                  "${createdAt.hour >= 12 ? 'PM' : 'AM'}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// 🔹 **Cancel Button or View Details**
            canCancel
                ? ElevatedButton.icon(
                    onPressed: () => _cancelRequest(context, requestId),
                    icon: const Icon(
                      Icons.cancel,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text("Cancel", style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                RequestDetailsScreen(requestId: requestId)),
                      );
                    },
                    child: const Text("View Details",
                        style: TextStyle(fontSize: 14, color: Colors.blue)),
                  ),
          ],
        ),
      ),
    );
  }

  /// 🔹 **Status Badge Styling**
  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor = Colors.white;

    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = Colors.orange;
        break;
      case 'approved':
        bgColor = Colors.green;
        break;
      case 'rejected':
        bgColor = Colors.red;
        break;
      case 'completed':
        bgColor = Colors.blue;
        break;
      default:
        bgColor = Colors.grey;
        textColor = Colors.black;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  /// 🔹 **Cancel Request Function**
  Future<void> _cancelRequest(BuildContext context, String requestId) async {
    await FirebaseFirestore.instance
        .collection('service_requests')
        .doc(requestId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Service request canceled.")),
    );
  }
}
