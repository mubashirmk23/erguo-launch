import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Define light and dark themes
final ThemeData lightTheme = ThemeData(
  scaffoldBackgroundColor: const Color(0xFFEDF6FF),
  fontFamily: 'DM Sans',
  primaryColor: const Color(0xFF000000),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFEDF6FF), // Light blue background
    elevation: 0, // Remove default shadow
    iconTheme: IconThemeData(color: Color(0xFF000000)), // Black icons
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Color(0xFF000000),
    ),
  ),
  colorScheme: const ColorScheme(
    primary: Color(0xFF000000), // Black
    onPrimary: Color(0xFFFFFFFF), // White text on black
    secondary: Color(0xFFFFFFFF), // White (used for cancel button)
    onSecondary: Color(0xFF000000), // Black text on white
    background: Color(0xFFEDF6FF), // Main app background
    onBackground: Color(0xFF000000), // Text color on background
    surface: Color(0xFFFFFFFF), // White for dialog background
    onSurface: Color(0xFF000000), // Text on dialog background
    error: Color(0xFFB00020), // Default error color
    onError: Color(0xFFFFFFFF), // Text on error color
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.normal, color: Color(0xFF000000)),
    bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFF000000)),
    titleLarge: TextStyle(
        fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF000000), // Black button
      foregroundColor: const Color(0xFFFFFFFF), // White text
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      backgroundColor: const Color(0xFFFFFFFF), // White button (cancel)
      foregroundColor: const Color(0xFF000000), // Black text
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  ),
  cardTheme: const CardThemeData(
    color: Color(0xFFFFFFFF), // White card background
    margin: EdgeInsets.symmetric(vertical: 8),
    elevation: 0.5, // Minimal shadow
    shadowColor: Colors.transparent, // Remove shadow
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Color(0xFFFFFFFF), // White dialog background
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Color(0xFF000000),
    ),
    contentTextStyle: TextStyle(
      fontSize: 16,
      color: Color(0xFF000000),
    ),
  ),
);

// Widget to apply the header background in dialogs
class DialogTitleContainer extends StatelessWidget {
  final String title;
  const DialogTitleContainer({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F6F7), // Greyish-White Title Background
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  visualDensity: VisualDensity.adaptivePlatformDensity,
);

// Riverpod provider for theme mode
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
