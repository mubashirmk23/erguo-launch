import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erguo/screens/client/client_timer_view_screen.dart';
import 'package:erguo/screens/client/payment_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 🔹 Providers for fetching data
final requestDetailsProvider = StreamProvider.family((ref, String requestId) {
  return FirebaseFirestore.instance
      .collection('service_requests')
      .doc(requestId)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

final workersProvider = FutureProvider.family((ref, String requestId) async {
  // 🔹 Step 1: Get the request document
  final requestDoc = await FirebaseFirestore.instance
      .collection('service_requests')
      .doc(requestId)
      .get();

  if (!requestDoc.exists) return [];

  final workersCode = requestDoc.data()?['workerCode'];
  if (workersCode == null) return [];

  // 🔹 Step 2: Query workers using the workersCode
  final workersSnapshot = await FirebaseFirestore.instance
      .collection('workers')
      .where('workerCode', isEqualTo: workersCode)
      .get();

  return workersSnapshot.docs.map((doc) => doc.data()).toList();
});

final billProvider = FutureProvider.family((ref, String requestId) async {
  final billSnapshot = await FirebaseFirestore.instance
      .collection('bills')
      .doc(requestId) // ✅ Get document directly using requestId
      .get();

  return billSnapshot.exists ? billSnapshot.data() : null;
});

// 🔹 UI: Request Details Screen
class RequestDetailsScreen extends ConsumerWidget {
  final String requestId;

  const RequestDetailsScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestStream = ref.watch(requestDetailsProvider(requestId));
    final workersAsync = ref.watch(workersProvider(requestId));
    final billAsync = ref.watch(billProvider(requestId));

    return Scaffold(
      appBar: AppBar(title: const Text("Request Details")),
      body: requestStream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text("Error: $error")),
        data: (requestData) {
          if (requestData == null) {
            return const Center(child: Text("Request not found"));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                _buildSectionTitle("Service Details"),
                _buildInfoTile("Service", requestData['serviceName']),
                _buildStatusTile("Status", requestData['status']),

                if (requestData['status'] == 'rejected')
                  _buildInfoTile(
                      "Rejection Reason", requestData['rejectionReason'],
                      color: Colors.red),

                if (requestData['status'] == 'approved')
                  _buildInfoTile("Contractor", requestData['contractorName'],
                      color: Colors.green),

                const SizedBox(height: 10),
                _buildSectionDivider(),

                // 🔹 Workers List
                if (requestData['status'] == 'Workers ready to work' ||
                    requestData['status'] == 'work started')
                  workersAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Center(child: Text("Error: $error")),
                    data: (workers) => workers.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("Assigned Workers"),
                              ...workers
                                  .map((worker) => _buildWorkerTile(worker)),
                              _buildSectionDivider(),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                // 🔹 Timer (Real-time)
// 🔹 Timer (Real-time)
                if (requestData['status'] == 'work started') ...[
                  _buildLiveTimer(requestId),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ClientTimerViewScreen(requestId: requestId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.timer, color: Colors.white),
                    label: const Text(
                      "View Live Timer",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],

                // 🔹 Bill Details
                if (requestData['status'] == 'bill ready')
                  billAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Center(child: Text("Error: $error")),
                    data: (billData) => billData != null
                        ? _buildBillSection(
                            context, billData) // ✅ Pass context here
                        : const Center(
                            child: Text("No bill details available")),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🔹 Section Title
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 🔹 Information Tile
  Widget _buildInfoTile(String label, String value,
      {Color color = Colors.black}) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value, style: TextStyle(color: color, fontSize: 16)),
    );
  }

  // 🔹 Status Tile with Color Coding
  Widget _buildStatusTile(String label, String status) {
    Color statusColor = Colors.grey;
    if (status == 'approved') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;
    if (status == 'bill ready') statusColor = Colors.blue;

    return _buildInfoTile(label, status, color: statusColor);
  }

  // 🔹 Worker Tile
  Widget _buildWorkerTile(Map<String, dynamic> worker) {
    return ListTile(
      leading: worker['photoUrl'] != null
          ? CircleAvatar(backgroundImage: NetworkImage(worker['photoUrl']))
          : const CircleAvatar(child: Icon(Icons.person)),
      title: Text(worker['name'],
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLiveTimer(String requestId) {
    final ref = FirebaseDatabase.instance.ref().child("timers/$requestId");

    return StreamBuilder(
      stream: ref.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const ListTile(
            title: Text("Live Timer"),
            subtitle: Text("Waiting for timer data..."),
          );
        }

        Map<String, dynamic> timerData =
            Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);

        return Card(
          elevation: 3,
          child: ListTile(
            leading: const Icon(Icons.timer, color: Colors.purple),
            title: const Text("Time Spent"),
            subtitle: Text(
              "${timerData['hours']} hrs ${timerData['minutes']} min ${timerData['seconds']} sec",
              style: const TextStyle(fontSize: 16, color: Colors.purple),
            ),
          ),
        );
      },
    );
  }

  // 🔹 Bill Section
  Widget _buildBillSection(
      BuildContext context, Map<String, dynamic> billData) {
    final totalAmount = (billData['totalPrice'] ?? 0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Bill Details"),
        ..._buildBillItems(billData['billItems']),
        _buildInfoTile("Total Time Worked", _formatTime(billData['timeWorked']),
            color: Colors.blue),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentScreen(
                    requestId: requestId,
                    amount: totalAmount), // ✅ Fixed amount parameter
              ),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          child: const Text("Proceed to Payment",
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  // 🔹 Bill Items
  List<Widget> _buildBillItems(List billItems) {
    return billItems.map((item) {
      return Card(
        elevation: 4,
        child: ListTile(
          title: Text("Item: ${item['itemName']}",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              "Quantity: ${item['quantity']}  |  Total: \$${item['totalPrice']}"),
        ),
      );
    }).toList();
  }

  // 🔹 Time Formatter
  String _formatTime(int timeInSeconds) {
    int hours = timeInSeconds ~/ 3600;
    int minutes = (timeInSeconds % 3600) ~/ 60;
    return "$hours hrs $minutes min";
  }

  // 🔹 Section Divider
  Widget _buildSectionDivider() {
    return const Divider(thickness: 1.5);
  }
}
