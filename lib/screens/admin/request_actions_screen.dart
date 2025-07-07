import 'dart:math';
import 'package:erguo/screens/admin/worker_allotment_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RequestActionsScreen extends StatefulWidget {
  final String requestId;

  const RequestActionsScreen({super.key, required this.requestId});

  @override
  State<RequestActionsScreen> createState() => _RequestActionsScreenState();
}

class _RequestActionsScreenState extends State<RequestActionsScreen> {
  bool isUpdating = false;
  String? requestStatus;

  @override
  void initState() {
    super.initState();
    _fetchRequestStatus();
  }

  Future<void> _fetchRequestStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('service_requests')
        .doc(widget.requestId)
        .get();
    if (doc.exists) {
      setState(() {
        requestStatus = doc['status'] ?? 'pending';
      });
    }
  }

  Future<void> approveRequest() async {
    final String generatedCode = (Random().nextInt(900000) + 100000).toString();

    setState(() => isUpdating = true);

    await FirebaseFirestore.instance
        .collection('service_requests')
        .doc(widget.requestId)
        .update({
      'status': 'approved',
      'workerCode': generatedCode,
    });

    setState(() {
      isUpdating = false;
      requestStatus = 'approved';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Request approved")),
    );

    // Fetch location
    final doc = await FirebaseFirestore.instance
        .collection('service_requests')
        .doc(widget.requestId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      GeoPoint? clientLocation;

      if (data['location'] != null && data['location'] is String) {
        final parts = (data['location'] as String).split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            clientLocation = GeoPoint(lat, lng);
          }
        }
      }

      final String? workCode = data['workerCode'];

      if (clientLocation != null && workCode != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WorkerAllotmentScreen(
              requestId: widget.requestId,
              clientLocation: clientLocation!,
              workCode: workCode,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Missing location or work code")),
        );
      }
    }
  }

  Future<void> rejectRequest() async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Request"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: "Enter reason"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => isUpdating = true);
              await FirebaseFirestore.instance
                  .collection('service_requests')
                  .doc(widget.requestId)
                  .update({
                'status': 'rejected',
                'rejectionReason': reasonController.text,
              });
              setState(() {
                isUpdating = false;
                requestStatus = 'rejected';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Request rejected")),
              );
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Request")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: isUpdating || requestStatus == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Status: $requestStatus",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                  const SizedBox(height: 20),
                  if (requestStatus == 'approved') ...[
                    const Text("Request is already approved.",
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() => isUpdating = true);

                        final doc = await FirebaseFirestore.instance
                            .collection('service_requests')
                            .doc(widget.requestId)
                            .get();

                        setState(() => isUpdating = false);

                        if (doc.exists) {
                          final data = doc.data()!;
                          GeoPoint? clientLocation;
                          if (data['location'] != null &&
                              data['location'] is String) {
                            final parts =
                                (data['location'] as String).split(',');
                            if (parts.length == 2) {
                              final lat = double.tryParse(parts[0].trim());
                              final lng = double.tryParse(parts[1].trim());
                              if (lat != null && lng != null) {
                                clientLocation = GeoPoint(lat, lng);
                              }
                            }
                          }

                          final String? workCode = data['workerCode'];

                          if (clientLocation != null && workCode != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WorkerAllotmentScreen(
                                  requestId: widget.requestId,
                                  clientLocation: clientLocation!,
                                  workCode: workCode,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Missing location or work code")),
                            );
                          }
                        }
                      },
                      child: const Text("Allot Workers"),
                    ),
                  ] else if (requestStatus == 'rejected') ...[
                    const Text("This request has been rejected.",
                        style: TextStyle(fontSize: 16, color: Colors.red)),
                  ] else ...[
                    ElevatedButton(
                      onPressed: approveRequest,
                      child: const Text("Approve Request"),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: rejectRequest,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Reject Request"),
                    ),
                  ]
                ],
              ),
      ),
    );
  }
}
