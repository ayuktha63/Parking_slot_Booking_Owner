import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; // Import for web check
import 'dart:io' show Platform; // Import for platform checks
import 'login_screen.dart';

// --- NEW DESIGN SYSTEM COLORS ---
const Color appBackground = Color(0xFF1C1C1E);
const Color cardSurface = Color(0xFF2C2C2E);
const Color appBarColor = Color(0xFF1C1C1E);
const Color infoItemBg = Color(0xFF3A3A3C);
const Color primaryText = Color(0xFFFFFFFF);
const Color secondaryText = Color(0xFFB0B0B5);
const Color hintText = Color(0xFF8E8E93);
const Color darkText = Color(0xFF000000);
const Color markerColor = Color.fromARGB(255, 215, 215, 215); // Accent
const Color elevatedButtonBg = Color(0xFFFFFFFF);
const Color errorRed = Color(0xFFD32F2F);
final Color shadow = Color.fromRGBO(0, 0, 0, 0.3);
// --- END NEW DESIGN SYSTEM COLORS ---

class ProfileScreen extends StatefulWidget {
  final String phone;

  const ProfileScreen({super.key, required this.phone});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _carSlotsController = TextEditingController();
  final TextEditingController _bikeSlotsController = TextEditingController();
  String _message = '';
  int? _totalCarSlots;
  int? _totalBikeSlots;
  String? _parkingAreaName;
  bool _isLoading = true;
  String apiHost = 'localhost'; // API Host variable

  @override
  void initState() {
    super.initState();
    // Set API host based on platform
    if (kIsWeb) {
      apiHost = '127.0.0.1';
    } else if (Platform.isAndroid) {
      apiHost = '10.0.2.2';
    }
    _fetchParkingAreaDetails();
  }

  Future<void> _fetchParkingAreaDetails() async {
    setState(() => _isLoading = true);
    try {
      // First, fetch the owner's details to get the associated parking area name
      final userResponse = await http.post(
        Uri.parse('http://$apiHost:4000/api/owner/login'), // Use apiHost
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phone,
        }),
      );
      final userData = jsonDecode(userResponse.body);
      final parkingAreaName = userData['parking_area_name'];

      if (parkingAreaName != null) {
        // Then, fetch the parking area details using the correct parking area name
        final parkingResponse = await http.get(Uri.parse(
            'http://$apiHost:4000/api/owner/parking_areas')); // Use apiHost
        final parkingAreas = jsonDecode(parkingResponse.body);
        final parkingArea = parkingAreas.firstWhere(
          (area) => area['name'] == parkingAreaName, // Corrected logic
          orElse: () => null,
        );

        setState(() {
          _parkingAreaName = parkingAreaName;
          _nameController.text = parkingAreaName;
          if (parkingArea != null) {
            _latController.text = parkingArea['location']['lat'].toString();
            _lngController.text = parkingArea['location']['lng'].toString();
            _carSlotsController.text =
                parkingArea['total_car_slots'].toString();
            _bikeSlotsController.text =
                parkingArea['total_bike_slots'].toString();
            _totalCarSlots = parkingArea['total_car_slots'];
            _totalBikeSlots = parkingArea['total_bike_slots'];
            _message = 'Current parking area details loaded';
          } else {
            _message = 'Parking area profile not found. Please update.';
          }
        });
      } else {
        setState(() {
          _message =
              'No parking area associated with this owner. Please update.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error fetching details: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateParkingArea() async {
    try {
      if (_nameController.text.isEmpty ||
          _latController.text.isEmpty ||
          _lngController.text.isEmpty ||
          _carSlotsController.text.isEmpty ||
          _bikeSlotsController.text.isEmpty) {
        setState(() => _message = 'All fields are required');
        _showErrorDialog('All fields are required');
        return;
      }

      double? lat = double.tryParse(_latController.text);
      double? lng = double.tryParse(_lngController.text);
      int? carSlots = int.tryParse(_carSlotsController.text);
      int? bikeSlots = int.tryParse(_bikeSlotsController.text);

      if (lat == null || lng == null) {
        setState(() => _message = 'Invalid latitude or longitude');
        _showErrorDialog('Invalid latitude or longitude');
        return;
      }
      if (carSlots == null ||
          bikeSlots == null ||
          carSlots < 0 ||
          bikeSlots < 0) {
        setState(() =>
            _message = 'Invalid slot numbers (must be non-negative integers)');
        _showErrorDialog(
            'Invalid slot numbers (must be non-negative integers)');
        return;
      }

      final response = await http.post(
        Uri.parse(
            'http://$apiHost:4000/api/owner/parking_areas'), // Use apiHost
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': widget.phone, // Owner's phone to identify the user
          'parking_area_name': _nameController.text, // The parking area's name
          'location': {'lat': lat, 'lng': lng},
          'total_car_slots': carSlots,
          'total_bike_slots': bikeSlots,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _message = data['message'] ?? 'Parking area updated successfully';
          _parkingAreaName = _nameController.text;
          _totalCarSlots = carSlots;
          _totalBikeSlots = bikeSlots;
        });
        // Re-fetch details to ensure full sync with the backend
        _fetchParkingAreaDetails();
      } else {
        setState(() => _message = data['message'] ?? 'Failed to update');
        _showErrorDialog(data['message'] ?? 'Failed to update');
      }
    } catch (e) {
      setState(() => _message = 'Error: $e');
      _showErrorDialog('Error: $e');
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardSurface, // New Color
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: errorRed), // New Color
            const SizedBox(width: 8),
            Text("Error",
                style: GoogleFonts.poppins(color: primaryText)), // New Style
          ],
        ),
        content: Text(message,
            style: GoogleFonts.poppins(color: secondaryText)), // New Style
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: primaryText)), // New Style
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground, // New Color
      appBar: AppBar(
        title: Text("Profile",
            style: GoogleFonts.poppins(color: primaryText)), // New Style
        elevation: 0,
        backgroundColor: appBarColor, // New Color
        iconTheme:
            IconThemeData(color: primaryText), // Ensure back button is white
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
              color: markerColor, // New Color
            ))
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: appBarColor, // New Color
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Parking Owner Profile",
                          style: GoogleFonts.poppins(
                            // New Style
                            color: primaryText,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Phone: ${widget.phone}",
                          style: GoogleFonts.poppins(
                            // New Style
                            color: secondaryText,
                            fontSize: 14,
                          ),
                        ),
                        if (_parkingAreaName != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Parking Area: $_parkingAreaName",
                            style: GoogleFonts.poppins(
                              // New Style
                              color: secondaryText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("Update Parking Area"),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardSurface, // New Color
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                // New Shadow
                                color: shadow,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _nameController,
                                label: "Parking Area Name",
                                icon: Icons.local_parking,
                                keyboardType: TextInputType.text,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _latController,
                                label: "Latitude",
                                icon: Icons.location_on,
                                keyboardType: TextInputType.numberWithOptions(
                                    decimal: true, signed: true),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _lngController,
                                label: "Longitude",
                                icon: Icons.location_on,
                                keyboardType: TextInputType.numberWithOptions(
                                    decimal: true, signed: true),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _carSlotsController,
                                label: "Total Car Slots",
                                icon: Icons.directions_car,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _bikeSlotsController,
                                label: "Total Bike Slots",
                                icon: Icons.motorcycle,
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              // New Style
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: elevatedButtonBg,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _updateParkingArea,
                            child: Text(
                              "Update Parking Area",
                              style: GoogleFonts.poppins(
                                  // New Style
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkText),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _message,
                          style: GoogleFonts.poppins(
                            // New Style
                            color: _message.contains('Error') ||
                                    _message.contains('Invalid')
                                ? errorRed // Use errorRed
                                : Colors.green, // Success color
                            fontSize: 14,
                          ),
                        ),
                        if (_totalCarSlots != null &&
                            _totalBikeSlots != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            width:
                                double.infinity, // Ensure it takes full width
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardSurface, // New Color
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  // New Shadow
                                  color: shadow,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle("Current Slot Counts"),
                                const SizedBox(height: 16),
                                Text('Total Car Slots: $_totalCarSlots',
                                    style: GoogleFonts.poppins(
                                        // New Style
                                        fontSize: 16,
                                        color: secondaryText)),
                                Text('Total Bike Slots: $_totalBikeSlots',
                                    style: GoogleFonts.poppins(
                                        // New Style
                                        fontSize: 16,
                                        color: secondaryText)),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              // New Style
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: errorRed, // New Color
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _logout,
                            child: Text(
                              "Logout",
                              style: GoogleFonts.poppins(
                                  // New Style
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText), // White text on red bg
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
            color: markerColor, // New Color
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            // New Style
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryText,
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: primaryText), // New Style
      decoration: InputDecoration(
        // New Style
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: hintText),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: hintText),
        filled: true,
        fillColor: infoItemBg,
      ),
    );
  }
}
