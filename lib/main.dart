import 'package:flutter/material.dart';
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
      home: const LoginScreen(),
    );
  }
}
