import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:erguo/providers/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _adminTapCount = 0;
  DateTime? _firstTapTime;

  @override
  Widget build(BuildContext context) {
    final selectedCity = ref.watch(selectedCityProvider) ?? "Unknown City";
    final showPopup = ref.watch(showRegisterPopupProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: _handleSecretAdminAccess,
              child: Text("Home - $selectedCity"),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1.0),
              child: Divider(height: 1, thickness: 1, color: Colors.black),
            ),
          ),
          drawer: _buildDrawer(context),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildServiceList(context),
              const SizedBox(height: 20),
            ],
          ),
          bottomNavigationBar: _buildBottomNavBar(context),
        ),

        // 👇 This is the cool floating popup
        if (showPopup)
          Positioned(
            right: 16,
            bottom: 100,
            child: RegisterWorkerPopup(
              onClose: () =>
                  ref.read(showRegisterPopupProvider.notifier).state = false,
            ),
          ),
      ],
    );
  }

  void _handleSecretAdminAccess() {
    final now = DateTime.now();

    if (_firstTapTime == null ||
        now.difference(_firstTapTime!) > const Duration(seconds: 3)) {
      _firstTapTime = now;
      _adminTapCount = 1;
    } else {
      _adminTapCount++;
    }

    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _firstTapTime = null;

      // Optional: Add a password dialog here if you want extra protection

      Navigator.pushNamed(context, "/admin-login");
    }
  }

  // 🔹 Service Selection List (with authentication check)
  Widget _buildServiceList(BuildContext context) {
    final serviceIcons = {
      "Plumbing": "assets/icons/plumbing.png",
      "Electrical Work": "assets/icons/electrical.png",
      "Garden Work": "assets/icons/garden.png",
      "Wooden Work": "assets/icons/woodwork.png",
      "STP": "assets/icons/stp.png",
      "AC Service": "assets/icons/ac_service.png",
    };

    final services = serviceIcons.keys.toList();

    return Align(
      alignment: Alignment.topCenter, // Ensures the container stays at the top
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 350, // Adjust this to prevent full-width stretch
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, // Overall white background
          borderRadius: BorderRadius.circular(16), // Rounded corners
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1), // Soft shadow
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(), // Prevent scrolling inside the grid
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 3 services per row
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _handleServiceTap(context, services[index]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    serviceIcons[services[index]]!,
                    width: 45,
                    height: 45,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    services[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkerPopup(BuildContext context, WidgetRef ref) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 1.0, end: 1.05),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      onEnd: () {
        // Repeat the animation
        Future.delayed(Duration.zero, () {
          ref
              .refresh(showRegisterPopupProvider.notifier)
              .update((state) => state); // just rebuilds
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.work, color: Colors.black87),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, "/workerRegister");
              },
              child: const Text(
                "Register as Worker",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                ref.read(showRegisterPopupProvider.notifier).state = false;
              },
              child: const Icon(Icons.close, size: 18, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Handle Service Tap (Check if user is logged in)
  void _handleServiceTap(BuildContext context, String serviceName) {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // ✅ Pass a Map instead of just a String
      Navigator.pushNamed(
        context,
        "/serviceRequest",
        arguments: {"serviceName": serviceName},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to request a service.")),
      );
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  // 🔹 Floating Bottom Navigation Bar
  Widget _buildBottomNavBar(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(left: 16, right: 16, bottom: 20), // Lift up
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30), // Rounded corners
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black, // Black background
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2), // Soft shadow
                blurRadius: 10,
                offset: const Offset(0, 4), // Moves shadow downward
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 10), // Inner padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(Icons.home, "Home", 0, context),
              _buildNavItem(Icons.list, "Requests", 1, context),
              _buildNavItem(Icons.person, "User", 2, context),
            ],
          ),
        ),
      ),
    );
  }

// 🔹 Navigation Item
  Widget _buildNavItem(
      IconData icon, String label, int index, BuildContext context) {
    return InkWell(
      onTap: () {
        if (index == 1) {
          Navigator.pushNamed(context, "/requests");
        } else if (index == 2) {
          _checkUserAndNavigate(context);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28), // White icon
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  // 🔹 Check if User is Logged In
  void _checkUserAndNavigate(BuildContext context) async {
    User? user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        await user.reload(); // Refresh authentication state
        user = FirebaseAuth.instance.currentUser; // Get updated user

        if (user != null) {
          Navigator.pushNamed(context, "/user");
          return;
        }
      }
    } catch (e) {
      print("Error checking user authentication: $e");
    }

    // If user is null or session expired, go to login
    Navigator.pushReplacementNamed(context, "/login");
  }

  // 🔹 Side Drawer for Admin/Worker Login
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text("Menu",
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          /*ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text("Login as Admin"),
            onTap: () {
              Navigator.pushNamed(context, "/admin-login");
            },
          ),*/
          ListTile(
            leading: const Icon(Icons.work),
            title: const Text("Login as Worker"),
            onTap: () {
              Navigator.pushNamed(context, "/workerLogin");
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.app_registration), // Optional: different icon
            title: const Text("Register as Worker"),
            onTap: () {
              Navigator.pushNamed(context, "/workerRegister");
            },
          ),
        ],
      ),
    );
  }
}

class RegisterWorkerPopup extends StatefulWidget {
  final VoidCallback onClose;

  const RegisterWorkerPopup({super.key, required this.onClose});

  @override
  State<RegisterWorkerPopup> createState() => _RegisterWorkerPopupState();
}

class _RegisterWorkerPopupState extends State<RegisterWorkerPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true); // continuous pulse

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        // 👈 Add this
        color: Colors.transparent, // Keep background transparent
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.work, color: Colors.black87),
              const SizedBox(width: 8),
              InkWell(
                // ✅ Already correct
                onTap: () {
                  Navigator.pushNamed(context, "/workerRegister");
                },
                child: const Text(
                  "Register as Worker",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onClose,
                child: const Icon(Icons.close, size: 18, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
