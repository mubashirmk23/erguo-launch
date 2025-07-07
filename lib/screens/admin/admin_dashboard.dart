import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:erguo/screens/admin/admin_request_details_screen.dart';

// Firestore reference
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// Fetching service requests
final serviceRequestsProvider = StreamProvider((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('service_requests')
      .orderBy('createdAt', descending: true)
      .snapshots();
});

// Fetching user details (client name)
final userDetailsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final userDoc =
      await ref.watch(firestoreProvider).collection('users').doc(userId).get();
  return userDoc.exists ? userDoc.data() : null;
});

// Formatting timestamp function
String formatTimestamp(dynamic timestamp) {
  if (timestamp is Timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }
  return 'N/A';
}

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsSnapshot = ref.watch(serviceRequestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEDF6FF), // Light blue background
      appBar: AppBar(
        title: const Text("Admin Dashboard",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: requestsSnapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text("Error: $error")),
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return const Center(child: Text("No service requests found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            itemCount: snapshot.docs.length,
            itemBuilder: (context, index) {
              final request = snapshot.docs[index];
              final data = request.data();
              final String userId = data['userId'] ?? '';

              return Consumer(
                builder: (context, ref, child) {
                  final userDetails = ref.watch(userDetailsProvider(userId));

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        data['serviceName'] ?? 'Unknown Service',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          userDetails.when(
                            loading: () => Container(
                              height: 12,
                              width: 80,
                              color: Colors.grey[300],
                            ),
                            error: (error, _) => const Text("Client: Unknown"),
                            data: (userData) => Text(
                              "Client: ${userData?['firstName'] ?? 'Unknown'}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Time: ${formatTimestamp(data['createdAt'])}",
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Status: ${data['status'] ?? 'pending'}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(data['status']),
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 18, color: Colors.black),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminRequestDetailsScreen(
                                requestId: request.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'Workers ready to work':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
