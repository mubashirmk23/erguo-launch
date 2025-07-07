import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';

class WorkerAllotmentScreen extends StatefulWidget {
  final String requestId;
  final GeoPoint clientLocation;
  final String workCode;

  const WorkerAllotmentScreen({
    super.key,
    required this.requestId,
    required this.clientLocation,
    required this.workCode,
  });

  @override
  _WorkerAllotmentScreenState createState() => _WorkerAllotmentScreenState();
}

class _WorkerAllotmentScreenState extends State<WorkerAllotmentScreen> {
  List<Map<String, dynamic>> workers = [];
  Set<String> selected = {};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    final double clientLat = widget.clientLocation.latitude;
    final double clientLng = widget.clientLocation.longitude;

    final snap = await FirebaseFirestore.instance.collection('workers').get();
    workers = [];

    for (var doc in snap.docs) {
      final w = doc.data();
      final String? locationStr = w['location'];
      if (locationStr == null || !locationStr.contains(',')) continue;

      final parts = locationStr.split(',');
      final double workerLat = double.tryParse(parts[0].trim()) ?? 0.0;
      final double workerLng = double.tryParse(parts[1].trim()) ?? 0.0;

      double dist = Geolocator.distanceBetween(
        clientLat,
        clientLng,
        workerLat,
        workerLng,
      );
      w['distance'] = dist;

      // 🔹 Get readable place from coordinates
      try {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(workerLat, workerLng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          w['placeName'] = "${place.locality}, ${place.administrativeArea}";
        } else {
          w['placeName'] = "Location unavailable";
        }
      } catch (_) {
        w['placeName'] = "Location error";
      }

      // 🔹 Today's work history
      DateTime today = DateTime.now();
      final historySnap = await FirebaseFirestore.instance
          .collection('workers')
          .doc(w['workerId'])
          .collection('workHistory')
          .where('date',
              isGreaterThan: Timestamp.fromDate(
                  DateTime(today.year, today.month, today.day)))
          .get();
      w['workedToday'] = historySnap.docs.length;
      workers.add(w);
    }

    // 🔹 Sort by joined status and distance
    workers.sort((a, b) {
      if (a['status'] == 'joined' && b['status'] != 'joined') return -1;
      if (b['status'] == 'joined' && a['status'] != 'joined') return 1;
      return (a['distance'] as double).compareTo(b['distance'] as double);
    });

    setState(() {});
  }

  void _showWhatsAppDialog(Map<String, dynamic> w) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Contact ${w['name']}?"),
        content: Text("Send them work code: ${widget.workCode}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("No")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final url = Uri.parse('https://wa.me/${w['phone']}?text='
                  'You%20have%20a%20job:%20Code%20${widget.workCode}');
              launchUrl(url);
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeAllotment() async {
    if (selected.isEmpty) return;
    setState(() => loading = true);

    for (var id in selected) {
      await FirebaseFirestore.instance.collection('workers').doc(id).update({
        'status': 'approved',
        'workerCode': widget.workCode, // ✅ Store the temporary work code
      });
    }

    await FirebaseFirestore.instance
        .collection('service_requests')
        .doc(widget.requestId)
        .update({'status': 'Workers ready to work'});

    setState(() => loading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text("Allot Workers")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Work Code: ${widget.workCode}",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: workers.length,
                    itemBuilder: (c, i) {
                      final w = workers[i];
                      final did = w['workerId'];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: w['photoUrl'] != null
                                ? NetworkImage(w['photoUrl'])
                                : null,
                            child: w['photoUrl'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(w['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w['phone']),
                              Text(
                                  "Location: ${w['placeName'] ?? 'Loading...'}"),
                              Text(
                                  "${(w['distance'] / 1000).toStringAsFixed(2)} km away"),
                              if (w['workedToday'] > 0)
                                Text("Worked today: ${w['workedToday']} times",
                                    style:
                                        const TextStyle(color: Colors.orange)),
                              Text("Status: ${w['status']}"),
                            ],
                          ),
                          trailing: Checkbox(
                            value: selected.contains(did),
                            onChanged: (_) {
                              setState(() {
                                did != null
                                    ? (selected.contains(did)
                                        ? selected.remove(did)
                                        : selected.add(did))
                                    : null;
                              });
                            },
                          ),
                          onTap: () => _showWhatsAppDialog(w),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: selected.isEmpty ? null : _finalizeAllotment,
                    child: const Text("Finalize Assignment"),
                  ),
                ),
              ],
            ),
    );
  }
}
