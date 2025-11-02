import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _message = '';

  Future<void> _register() async {
    try {
      if (_phoneController.text.isEmpty ||
          _nameController.text.isEmpty ||
          _passwordController.text.isEmpty) {
        setState(() => _message = 'All fields are required');
        return;
      }

      final response = await http.post(
        Uri.parse('http://localhost:4000/api/owner/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text,
          'parking_area_name': _nameController.text,
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);
      setState(
          () => _message = data['message'] ?? 'Registration attempt failed');

      if (response.statusCode == 200) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _message = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E), // appBackground
      appBar: AppBar(
        title: const Text("Register"),
        elevation: 0,
        backgroundColor: const Color(0xFF1C1C1E), // appBarColor
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E), // Matches background
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Create Account",
                    style: TextStyle(
                      color: Color(0xFFFFFFFF), // primaryText
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Sign up to manage your parking area",
                    style: TextStyle(
                      color: const Color(0xFFB0B0B5), // secondaryText
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Registration Details"),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E), // cardSurface
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromRGBO(0, 0, 0, 0.3), // shadow
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _phoneController,
                          label: "Phone Number",
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _nameController,
                          label: "Parking Area Name",
                          icon: Icons.local_parking,
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          label: "Password",
                          icon: Icons.lock,
                          keyboardType: TextInputType.text,
                          obscureText: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor:
                            const Color(0xFFFFFFFF), // elevatedButtonBg
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _register,
                      child: const Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000), // darkText
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _message,
                    style: TextStyle(
                      color: _message.contains('Error') ||
                              _message.contains('required')
                          ? const Color(0xFFD32F2F) // errorRed
                          : const Color(0xFFFFFFFF), // success text as white
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 215, 215, 215), // markerColor
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFFFF), // primaryText
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Color(0xFFFFFFFF)), // primaryText
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8E8E93)), // hintText
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A3C)), // infoItemBg
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color.fromARGB(255, 215, 215, 215)), // markerColor
        ),
        prefixIcon: Icon(icon,
            color: const Color.fromARGB(255, 215, 215, 215)), // markerColor
        filled: true,
        fillColor: const Color(0xFF3A3A3C), // infoItemBg
      ),
    );
  }
}
