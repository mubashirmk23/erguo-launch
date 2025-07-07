import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 🔹 **Riverpod Provider for User Data**
final userProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  return userDoc.exists ? userDoc.data() as Map<String, dynamic> : null;
});

/// 🔹 **UserScreen Using Riverpod**
class UserScreen extends ConsumerStatefulWidget {
  const UserScreen({super.key});

  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends ConsumerState<UserScreen> {
  final TextEditingController phoneController = TextEditingController();
  bool isEditingPhone = false;

  /// 🔹 **Update Phone Number in Firestore**
  Future<void> _updatePhoneNumber(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'phone': phoneController.text});
    setState(() => isEditingPhone = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Phone number updated successfully!")),
    );
    ref.invalidate(userProvider); // Refresh user data
  }
/// 🔹 **Calculate Age from DOB String**
int _calculateAge(String dob) {
  try {
    DateTime birthDate = DateFormat("dd/MM/yyyy").parse(dob);
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || 
       (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  } catch (e) {
    return 0; // Return 0 if parsing fails
  }
}

  /// 🔹 **Sign Out User**
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
         leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => Navigator.pop(context),
  ),
        title: const Text("User Profile"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text("Error: $error")),
          data: (userData) {
            if (userData == null) {
              return const Center(child: Text("No user data found."));
            }

            /// 🔹 **Extracting User Data**
            final userId = FirebaseAuth.instance.currentUser!.uid;
            final firstName = userData['firstName'] ?? "N/A";
            final lastName = userData['lastName'] ?? "N/A";
            final phoneNumber = userData['phone'] ?? "N/A";
final age = _calculateAge(userData['dob'] ?? "N/A").toString();

            phoneController.text = phoneNumber;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🔹 **Profile Card**
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// 🔹 **First & Last Name**
                        _buildInfoRow("First Name", firstName),
                        _buildInfoRow("Last Name", lastName),
                        const Divider(),

                        /// 🔹 **Phone Number with Edit Option**
                        isEditingPhone
                            ? TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: "Phone Number",
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () => _updatePhoneNumber(userId),
                                  ),
                                ),
                              )
                            : _buildEditableRow("Phone", phoneNumber, Icons.edit, () {
                                setState(() => isEditingPhone = true);
                              }),
                        const Divider(),

                        /// 🔹 **Age**
                        _buildInfoRow("Age", age),
                      ],
                    ),
                  ),
                ),

                const Spacer(), // Pushes Sign Out button to bottom

                /// 🔹 **Sign Out Button**
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text("Sign Out", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 🔹 **Helper Widget for Info Display**
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  /// 🔹 **Helper Widget for Editable Row**
  Widget _buildEditableRow(String label, String value, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              IconButton(icon: Icon(icon, color: Colors.blue), onPressed: onTap),
            ],
          ),
        ],
      ),
    );
  }
}
