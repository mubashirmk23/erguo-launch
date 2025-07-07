import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:erguo/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRegisterScreen extends ConsumerStatefulWidget {
  const UserRegisterScreen({super.key});

  @override
  _UserRegisterScreenState createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends ConsumerState<UserRegisterScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController =
      TextEditingController(text: "+91"); // Auto-insert +91
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  String selectedGender = "Male"; // Default selection
  bool isLoading = false;

  void _pickDOB() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime(DateTime.now().year - 18), // Min 18 years old
    );

    if (pickedDate != null) {
      setState(() {
        dobController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  void _register() async {
    setState(() => isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);

    User? user = await authRepo.registerWithEmail(
      emailController.text.trim(),
      passwordController.text.trim(),
      firstNameController.text.trim(),
      lastNameController.text.trim(),
      phoneController.text.trim(),
      dobController.text.trim(),
      selectedGender,
    );

    setState(() => isLoading = false);

    if (user != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration failed. Try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFEDF6FF), // Light Blue Background
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40), // Push content down
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Create an Account",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DM Sans',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Sign up to continue",
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'DM Sans',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30), // More spacing before form

            // 🔹 White Card for Form Fields
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTextField(firstNameController, "First Name"),
                  _buildTextField(lastNameController, "Last Name"),
                  _buildTextField(emailController, "Email",
                      keyboardType: TextInputType.emailAddress),
                  _buildTextField(phoneController, "Phone Number",
                      keyboardType: TextInputType.phone),

                  // 🔹 DOB Picker
                  GestureDetector(
                    onTap: _pickDOB,
                    child: AbsorbPointer(
                      child: _buildTextField(dobController, "Date of Birth",
                          icon: Icons.calendar_today),
                    ),
                  ),

                  _buildGenderSelection(),
                  _buildTextField(passwordController, "Password",
                      obscureText: true),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Register Button
            ElevatedButton(
              onPressed: isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Register",
                      style: TextStyle(fontSize: 18, fontFamily: 'DM Sans'),
                    ),
            ),

            const SizedBox(height: 15),

            // 🔹 Login Instead
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text(
                "Already have an account? Login",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'DM Sans',
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // 🔹 Custom Input Field Widget
  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text,
      bool obscureText = false,
      IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontFamily: 'DM Sans'),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.black) : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  // 🔹 Gender Selection Widget
  Widget _buildGenderSelection() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Gender", style: TextStyle(fontSize: 16)),
          const SizedBox(height: 5),
          ToggleButtons(
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minWidth: 100, minHeight: 40),
            isSelected: [selectedGender == "Male", selectedGender == "Female"],
            selectedColor: Colors.white,
            fillColor: Colors.black,
            color: Colors.black,
            children: const [
              Text("Male", style: TextStyle(fontSize: 14)),
              Text("Female", style: TextStyle(fontSize: 14)),
            ],
            onPressed: (index) {
              setState(() {
                selectedGender = index == 0 ? "Male" : "Female";
              });
            },
          ),
        ],
      ),
    );
  }
}
