import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'waiting_screen.dart';

class ServiceRequestState {
  final TextEditingController problemController;
  final TextEditingController addressController;
  final List<File> mediaFiles;
  final List<String> uploadedMediaUrls;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final String? selectedLocation;
  final bool isLocationLoading;
  final bool isSubmitting;
  final String? scheduledDateText; // For formatted date display
  final String? scheduledTimeText; // For formatted time display
  final bool isUploadingMedia;

  ServiceRequestState({
    this.isUploadingMedia = false,
    TextEditingController? problemController,
    TextEditingController? addressController,
    this.mediaFiles = const [],
    this.uploadedMediaUrls = const [],
    this.selectedDate,
    this.selectedTime,
    this.selectedLocation,
    this.isLocationLoading = false,
    this.isSubmitting = false,
    this.scheduledDateText = '', // Default empty string
    this.scheduledTimeText = '', // Default empty string
  })  : problemController = problemController ?? TextEditingController(),
        addressController = addressController ?? TextEditingController();

  ServiceRequestState copyWith({
    bool? isUploadingMedia,
    String? scheduledDateText,
    String? scheduledTimeText,
    TextEditingController? problemController,
    TextEditingController? addressController,
    List<File>? mediaFiles,
    List<String>? uploadedMediaUrls,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    String? selectedLocation,
    bool? isLocationLoading,
    bool? isSubmitting,
  }) {
    return ServiceRequestState(
      isUploadingMedia: isUploadingMedia ?? this.isUploadingMedia,
      scheduledDateText: scheduledDateText ?? this.scheduledDateText,
      scheduledTimeText: scheduledTimeText ?? this.scheduledTimeText,
      problemController: problemController ?? this.problemController,
      addressController: addressController ?? this.addressController,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      uploadedMediaUrls: uploadedMediaUrls ?? this.uploadedMediaUrls,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      isLocationLoading: isLocationLoading ?? this.isLocationLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

final serviceRequestProvider =
    StateNotifierProvider<ServiceRequestNotifier, ServiceRequestState>(
  (ref) => ServiceRequestNotifier(),
);

class ServiceRequestNotifier extends StateNotifier<ServiceRequestState> {
  ServiceRequestNotifier() : super(ServiceRequestState());

  final supabase = Supabase.instance.client;

  Future<String> getSupabaseUUID() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists && userDoc.data()?['supabaseUUID'] != null) {
      return userDoc.data()?['supabaseUUID'];
    } else {
      final String newUUID = const Uuid().v4();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'supabaseUUID': newUUID},
        SetOptions(merge: true),
      );
      return newUUID;
    }
  }

  Future<void> pickMedia() async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      await uploadMediaToSupabase(file);
    }
  }

  Future<void> uploadMediaToSupabase(File file) async {
    try {
      state = state.copyWith(isUploadingMedia: true); // Start loading

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final String supabaseUUID = await getSupabaseUUID();
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final String filePath = "$supabaseUUID/$fileName";

      Uint8List fileBytes = await file.readAsBytes();

      await supabase.storage.from('user-media').uploadBinary(
            filePath,
            fileBytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: false),
          );

      String publicUrl =
          supabase.storage.from('user-media').getPublicUrl(filePath);

      state = state.copyWith(
        mediaFiles: [...state.mediaFiles, file],
        uploadedMediaUrls: [...state.uploadedMediaUrls, publicUrl],
        isUploadingMedia: false, // Stop loading after upload
      );
    } catch (e) {
      state = state.copyWith(
          isUploadingMedia: false); // Stop loading even if there's an error
      print("Upload error: $e");
    }
  }

  Future<void> showSchedulePopup(BuildContext context) async {
    DateTime tempDate = state.selectedDate ?? DateTime.now();
    TimeOfDay tempTime = state.selectedTime ?? TimeOfDay.now();

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFFF5F6F7), // Dialog background color
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "Schedule for Later",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Divider(
                      color: Colors.grey.shade300,
                      thickness: 1), // Light divider

                  const SizedBox(height: 12),

                  ListTile(
                    title: Text(
                      "Selected Date: ${tempDate.toLocal().toString().split(' ')[0]}",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    trailing:
                        const Icon(Icons.calendar_today, color: Colors.black),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: tempDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setModalState(() => tempDate = picked);
                      }
                    },
                  ),

                  ListTile(
                    title: Text(
                      "Selected Time: ${tempTime.format(context)}",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    trailing:
                        const Icon(Icons.access_time, color: Colors.black),
                    onTap: () async {
                      TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: tempTime,
                      );
                      if (picked != null) {
                        setModalState(() => tempTime = picked);
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          onPressed: () {
                            state = state.copyWith(
                              selectedDate: tempDate,
                              selectedTime: tempTime,
                              scheduledDateText:
                                  tempDate.toLocal().toString().split(' ')[0],
                              scheduledTimeText: tempTime.format(context),
                            );
                            Navigator.pop(context);
                          },
                          label: "Confirm",
                          isPrimary: true, // Black button, white text
                          icon: Icons.check,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          onPressed: () => Navigator.pop(context),
                          label: "Cancel",
                          isPrimary: false, // White button, black text
                          icon: Icons.close,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> proceed(BuildContext context, String serviceName) async {
    if (state.problemController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a problem description")),
      );
      return;
    }

    if (state.addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an address")),
      );
      return;
    }

    if (state.mediaFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload at least one media file")),
      );
      return;
    }

    try {
      state = state.copyWith(isSubmitting: true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      DocumentReference requestRef =
          await FirebaseFirestore.instance.collection('service_requests').add({
        'userId': user.uid,
        'serviceName': serviceName,
        'problem': state.problemController.text,
        'address': state.addressController.text,
        'mediaUrls': state.uploadedMediaUrls,
        'location': state.selectedLocation,
        'date': state.selectedDate?.toIso8601String(),
        'time': state.selectedTime != null
            ? "${state.selectedTime!.hour}:${state.selectedTime!.minute}"
            : null,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingScreen(requestId: requestRef.id),
        ),
      );

      state = ServiceRequestState();
    } catch (e) {
      print("Error submitting request: $e");
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> selectLocation() async {
    state = state.copyWith(isLocationLoading: true);

    var status = await Permission.location.request();
    if (!status.isGranted) {
      state = state.copyWith(isLocationLoading: false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      final String locationString =
          "${position.latitude}, ${position.longitude}";

      state = state.copyWith(
        selectedLocation: locationString, // ✅ store coordinates
        isLocationLoading: false,
      );

      print("Location received: $locationString");
    } catch (e) {
      state = state.copyWith(isLocationLoading: false);
      print("Error fetching location: $e");
    }
  }
}

class ServiceRequestScreen extends ConsumerWidget {
  final String serviceName;

  const ServiceRequestScreen({super.key, required this.serviceName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serviceRequestProvider);
    final notifier = ref.read(serviceRequestProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text("Request $serviceName")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CustomTextField(
                controller: state.problemController,
                label: "Describe the Problem"),
            const SizedBox(height: 12),
            CustomTextField(
                controller: state.addressController, label: "Address"),
            const SizedBox(height: 12),
            CustomButton(
              onPressed: () =>
                  notifier.pickMedia(), // ✅ Wrap in a synchronous function
              label: state.isUploadingMedia
                  ? "Uploading..."
                  : "Add Media (${state.mediaFiles.length})",
              icon: Icons.camera_alt,
              isPrimary: false,
            ),
            const SizedBox(height: 12),
            CustomButton(
              onPressed: notifier.selectLocation,
              label: state.isLocationLoading
                  ? "Getting Location..."
                  : (state.selectedLocation != null
                      ? "Location Selected"
                      : "Select Location"),
              icon: Icons.location_on,
              isPrimary: false,
            ),
            if (state.isLocationLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(), // Show loading indicator
              ),
            const SizedBox(height: 12),
            CustomButton(
              onPressed: () => notifier.showSchedulePopup(context),
              label: (state.scheduledDateText != null &&
                      state.scheduledDateText!.isNotEmpty &&
                      state.scheduledTimeText != null &&
                      state.scheduledTimeText!.isNotEmpty)
                  ? "Scheduled: ${state.scheduledDateText} at ${state.scheduledTimeText}"
                  : "Schedule for Later",

              icon: Icons.schedule,
              isPrimary: false, // White background, black text
            ),
            const SizedBox(height: 12),
            CustomButton(
              onPressed: () => notifier.proceed(context, serviceName),
              label: state.isSubmitting ? "Submitting..." : "Proceed",
              icon: Icons.arrow_forward, // Add arrow icon for proceed
              isPrimary: true, // Black background, white text
            ),
          ],
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final bool isPrimary;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isPrimary = true,
    this.icon, // Allow optional icons
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // Makes button take full width
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.black : Colors.white,
          foregroundColor: isPrimary ? Colors.white : Colors.black,
          side: const BorderSide(color: Colors.black),
          padding: const EdgeInsets.symmetric(
              vertical: 16), // Increase button height
        ),
        icon: icon != null
            ? Icon(icon, size: 20)
            : const SizedBox.shrink(), // Add icon if provided
        label: Text(label,
            style: const TextStyle(fontSize: 16)), // Adjust font size
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isMultiline;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: isMultiline ? 5 : 1,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }
}
