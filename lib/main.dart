import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // For Lottie animation
import 'package:google_fonts/google_fonts.dart'; // For Google Fonts
import 'login_screen.dart';

void main() {
  runApp(const ParkingAreaOwnerApp());
}

class ParkingAreaOwnerApp extends StatelessWidget {
  const ParkingAreaOwnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parking Area Owner App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoadingScreen(), // Start with LoadingScreen
      debugShowCheckedModeBanner: false, // Add this line to remove debug banner
    );
  }
}

// Loading Screen Widget
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin(); // Call navigation method
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(
        const Duration(seconds: 2)); // Simulate loading for 2 seconds
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[100],
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              '/lottie/main_car.json',
              width: 300,
              height: 300,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              "Parking Your Vehicle...",
              style: TextStyle(
                fontSize: 24,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
