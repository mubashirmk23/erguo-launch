import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 🔹 **Admin Login State Management with Riverpod**
class AdminLoginNotifier extends StateNotifier<bool> {
  AdminLoginNotifier() : super(false);

  Future<String?> loginAdmin(String enteredCode) async {
    if (enteredCode.isEmpty || enteredCode.length < 6) return "Enter full admin code.";

    state = true; // Show loading indicator

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .where('code', isEqualTo: int.tryParse(enteredCode))
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var adminDoc = querySnapshot.docs.first;
        String adminName = adminDoc['name'];
        state = false;
        return "Welcome, $adminName!";
      } else {
        state = false;
        return "Invalid admin code.";
      }
    } catch (e) {
      state = false;
      return "Error: $e";
    }
  }
}

final adminLoginProvider = StateNotifierProvider<AdminLoginNotifier, bool>((ref) {
  return AdminLoginNotifier();
});

/// 🔹 **Admin Login Screen with OTP-style Input**
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  _AdminLoginScreenState createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  void _onCodeEntered() async {
    String enteredCode = _controllers.map((c) => c.text).join();
    if (enteredCode.length < 6) return;

    String? result = await ref.read(adminLoginProvider.notifier).loginAdmin(enteredCode);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
      if (result.startsWith("Welcome")) {
        Navigator.pushReplacementNamed(context, '/adminDashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(adminLoginProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Login", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// 🔹 **Title**
            const Text(
              "Enter Admin Code",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            /// 🔹 **OTP-style Input Fields with RawKeyboardListener**
            RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: (RawKeyEvent event) {
                if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                  for (int i = 0; i < 6; i++) {
                    if (_focusNodes[i].hasFocus && _controllers[i].text.isEmpty && i > 0) {
                      FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
                      break;
                    }
                  }
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        counterText: "",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          if (index < 5) {
                            FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                          } else {
                            _onCodeEntered();
                          }
                        }
                      },
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            /// 🔹 **Login Button or Loading Indicator**
            isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onCodeEntered,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}
