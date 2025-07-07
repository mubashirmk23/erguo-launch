import 'package:erguo/screens/image_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'request_actions_screen.dart'; // Navigate to this screen for status changes

class AdminRequestDetailsScreen extends StatefulWidget {
  final String requestId;

  const AdminRequestDetailsScreen({super.key, required this.requestId});

  @override
  _AdminRequestDetailsScreenState createState() =>
      _AdminRequestDetailsScreenState();
}

class _AdminRequestDetailsScreenState extends State<AdminRequestDetailsScreen> {
  // Fetch user details
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.exists ? userDoc.data() : null;
    } catch (e) {
      print("Error fetching user details: $e");
      return null;
    }
  }

  // Download all media
  void _downloadAllMedia(List<String> mediaUrls) async {
    try {
      Dio dio = Dio();
      List<Future> downloadFutures = [];
      for (int i = 0; i < mediaUrls.length; i++) {
        String fileName = "media_${widget.requestId}_$i.jpg";
        downloadFutures.add(dio.download(
            mediaUrls[i], "/storage/emulated/0/Download/$fileName"));
      }
      await Future.wait(downloadFutures);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("All media downloaded")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Download failed: $e")));
    }
  }

  // Show location in Google Maps
  void _showLocation(String location) {
    final Uri googleMapsUri =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$location");
    launchUrl(googleMapsUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Details"),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: Colors.black),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('service_requests')
            .doc(widget.requestId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Request not found."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final Timestamp createdAtTimestamp =
              data['createdAt'] ?? Timestamp.now();
          final String formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss')
              .format(createdAtTimestamp.toDate());
          final String userId = data['userId'] ?? '';
          final String location = data['location'] ?? 'N/A';
          final String status = data['status'] ?? 'pending';
          final String? workerCode =
              data['workerCode']; // workerCode from request

          Future<List<Map<String, dynamic>>> fetchJoinedWorkers(
              String code) async {
            final workersSnapshot = await FirebaseFirestore.instance
                .collection('workers')
                .where('workerCode', isEqualTo: code)
                .where('status', isEqualTo: 'joined')
                .get();

            return workersSnapshot.docs.map((doc) => doc.data()).toList();
          }

          return FutureBuilder<Map<String, dynamic>?>(
            future: getUserDetails(userId),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = userSnapshot.data;
              final String clientName = userData?['firstName'] ?? 'Unknown';
              final String phoneNumber = userData?['phone'] ?? 'No Phone';

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Request ID: ${widget.requestId}",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Client: $clientName"),
                      Text("Phone: $phoneNumber"),
                      Text("Service: ${data['serviceName'] ?? 'N/A'}"),
                      Text("Address: ${data['address'] ?? 'N/A'}"),
                      Text("Time: $formattedTime"),
                      Text("Status: $status",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue)),

                      if (status == "rejected")
                        Text(
                          "Rejection Reason: ${data['rejectionReason'] ?? 'Not provided'}",
                          style:
                              const TextStyle(fontSize: 16, color: Colors.red),
                        ),

                      if (status == "Workers ready to work")
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: fetchJoinedWorkers(workerCode ?? ''),
                          builder: (context, workerSnapshot) {
                            if (workerSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final joinedWorkers = workerSnapshot.data ?? [];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                const Text(
                                  "Joined Workers:",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                if (joinedWorkers.isEmpty)
                                  const Text("No workers have joined yet.")
                                else ...[
                                  Column(
                                    children: joinedWorkers.map((w) {
                                      return ListTile(
                                        leading: const Icon(Icons.person),
                                        title: Text(w['name'] ?? 'No Name'),
                                        subtitle:
                                            Text(w['phone'] ?? 'No Phone'),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection('service_requests')
                                          .doc(widget.requestId)
                                          .update({'status': 'Final Proceed'});

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Status changed to Final Proceed")),
                                      );
                                      setState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green),
                                    child: const Text("Mark as Final Proceed"),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 10),

                      // Show media if any
                      if (data['mediaUrls'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Media:",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    (data['mediaUrls'] as List).map((url) {
                                  return Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ImageViewerScreen(
                                                imageUrl: url),
                                          ),
                                        );
                                      },
                                      child: Image.network(
                                        url,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _downloadAllMedia(
                                  List<String>.from(data['mediaUrls'])),
                              child: const Text("Download All Media"),
                            ),
                          ],
                        ),

                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _showLocation(location),
                        child: const Text("Show Location"),
                      ),
                      const SizedBox(height: 20),

                      if (status == "pending" || status == "approved")
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RequestActionsScreen(
                                    requestId: widget.requestId),
                              ),
                            );
                          },
                          child: const Text("Manage Request"),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
