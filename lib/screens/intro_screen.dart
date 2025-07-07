import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:erguo/providers/providers.dart'; // Import shared provider

class IntroScreen extends ConsumerWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Your Location",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 2, height: 20),
            _cityButton(context, ref, "Thrissur", true),
            _cityButton(context, ref, "Alappuzha", false),
            _cityButton(context, ref, "Ernakulam", false),
            _cityButton(context, ref, "Palakkad", false),
          ],
        ),
      ),
    );
  }

  Widget _cityButton(BuildContext context, WidgetRef ref, String city, bool isAvailable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6), // Add space between rows
      child: Material(
        color: Colors.transparent, // Keeps background transparent
        child: InkWell(
          onTap: () {
            if (isAvailable) {
              ref.read(selectedCityProvider.notifier).state = city;
              Future.microtask(() {
                Navigator.pushReplacementNamed(context, "/home");
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("We are not yet in this place, but soon we will be there!"),
                ),
              );
            }
          },
          splashColor: Colors.black26, // Tap effect color
          highlightColor: Colors.black12, // Press effect color
          borderRadius: BorderRadius.circular(10), // Rounded ripple effect
          child: Container(
            width: double.infinity, // Make the whole row touchable
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12), // Add padding
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10), // Rounded edges
              border: Border.all(
                color: isAvailable ? Colors.black : Colors.grey, // Border color based on availability
                width: 1.5,
              ),
            ),
            child: Text(
              city,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isAvailable ? Colors.black : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
