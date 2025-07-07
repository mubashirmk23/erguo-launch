import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class WorkerRegisterScreen extends StatefulWidget {
  const WorkerRegisterScreen({super.key});

  @override
  _WorkerRegisterScreenState createState() => _WorkerRegisterScreenState();
}

class _WorkerRegisterScreenState extends State<WorkerRegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController(text: "+91");
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final supabase = Supabase.instance.client;
  Position? _currentPosition;
  String? _workerId;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
    });
  }

  Future<String?> _uploadImage(File imageFile, String workerId) async {
    try {
      final fileName = "$workerId.jpg";
      final storagePath = "workers/$fileName";

      final response = await supabase.storage.from('worker_photos').upload(
            storagePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      if (response.isNotEmpty) {
        return supabase.storage.from('worker_photos').getPublicUrl(storagePath);
      }
    } catch (e) {
      print("Error uploading image: $e");
    }
    return null;
  }

  Future<void> _saveWorkerDetails() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.length < 13 ||
        _selectedImage == null ||
        _currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please fill all fields and verify location.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final workerId = _workerId ?? const Uuid().v4();
      _workerId = workerId;

      final imageUrl = await _uploadImage(_selectedImage!, workerId);

      await FirebaseFirestore.instance.collection('workers').doc(workerId).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'photoUrl': imageUrl ?? '',
        'location':
            "${_currentPosition!.latitude},${_currentPosition!.longitude}",
        'workerId': workerId,
        'status': 'just joined',
        'experience': _experienceController.text.trim(), // ✅ New field
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registered successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Error saving details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to register. Try again.")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register as Worker")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Enter Your Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: "Full Name", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: "Phone Number", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _experienceController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: "Experience (e.g. 2 years)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : null,
                  child: _selectedImage == null
                      ? const Icon(Icons.camera_alt, size: 30)
                      : null,
                ),
              ),
              const SizedBox(height: 5),
              const Text("Tap to select a photo",
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _getLocation,
                    icon: const Icon(Icons.location_on),
                    label: const Text("Verify Location"),
                  ),
                  const SizedBox(width: 10),
                  if (_currentPosition != null)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveWorkerDetails,
                        child: const Text("Register"),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
