import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; // Import for web check
import 'login_screen.dart'; // Assuming this is the Owner Login Screen

// --- DESIGN SYSTEM COLORS (Dark Mode) ---
const Color appBackground = Color(0xFF1C1C1E);
const Color cardSurface = Color(0xFF2C2C2E);
const Color appBarColor = Color(0xFF1C1C1E);
const Color infoItemBg = Color(0xFF3A3A3C);
const Color primaryText = Color(0xFFFFFFFF);
const Color secondaryText = Color(0xFFB0B0B5);
const Color hintText = Color(0xFF8E8E93);
const Color darkText = Color(0xFF000000);
const Color markerColor = Color(0xFF0A84FF); // Blue Accent
const Color elevatedButtonBg = Color(0xFFFFFFFF);
const Color errorRed = Color(0xFFD32F2F);
final Color shadow = Color.fromRGBO(0, 0, 0, 0.3);
// --- END DESIGN SYSTEM COLORS ---

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

  String apiHost = 'backend-parking-bk8y.onrender.com';
  String apiScheme = 'https';

  @override
  void initState() {
    super.initState();
    // Set API host based on platform
    if (kIsWeb &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
      apiHost = '127.0.0.1:3000';
      apiScheme = 'http';
    }
    _fetchParkingAreaDetails();
  }

  Future<void> _fetchParkingAreaDetails() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch the owner's details to get the associated parking area name
      final userResponse = await http.post(
        Uri.parse('$apiScheme://$apiHost/api/owner/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phone,
        }),
      );

      if (userResponse.statusCode != 200) {
        throw Exception("Failed to verify owner credentials.");
      }

      final userData = jsonDecode(userResponse.body);
      final parkingAreaName = userData['parking_area_name'];

      if (parkingAreaName != null) {
        // 2. Fetch all parking areas
        final parkingResponse = await http
            .get(Uri.parse('$apiScheme://$apiHost/api/owner/parking_areas'));

        if (parkingResponse.statusCode != 200) {
          throw Exception("Failed to fetch parking area list.");
        }

        final parkingAreas = jsonDecode(parkingResponse.body);

        // 3. Find the specific parking area matching the owner's linked name
        final parkingArea = parkingAreas.firstWhere(
          (area) => area['name'] == parkingAreaName,
          orElse: () => null,
        );

        setState(() {
          _parkingAreaName = parkingAreaName;
          _nameController.text = parkingAreaName;
          if (parkingArea != null) {
            _latController.text =
                parkingArea['location']['lat']?.toString() ?? '';
            _lngController.text =
                parkingArea['location']['lng']?.toString() ?? '';
            _carSlotsController.text =
                parkingArea['total_car_slots']?.toString() ?? '0';
            _bikeSlotsController.text =
                parkingArea['total_bike_slots']?.toString() ?? '0';
            _totalCarSlots = parkingArea['total_car_slots'];
            _totalBikeSlots = parkingArea['total_bike_slots'];
            _message = 'Current parking area details loaded';
          } else {
            _message =
                'Parking area profile not found. Please set capacity/location.';
          }
        });
      } else {
        setState(() {
          _message =
              'No parking area associated with this owner. Please update.';
        });
      }
    } catch (e) {
      print('Error fetching details: $e');
      setState(() {
        _message = 'Error fetching details: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateParkingArea() async {
    // Basic validation
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

    if (lat == null ||
        lng == null ||
        carSlots == null ||
        bikeSlots == null ||
        carSlots < 0 ||
        bikeSlots < 0) {
      setState(() => _message = 'Invalid input for coordinates or slots.');
      _showErrorDialog(
          'Invalid input for coordinates or slots (must be non-negative numbers).');
      return;
    }

    // Warn owner about Hybrid Model slot reset on capacity change
    bool capacityChanged =
        carSlots != _totalCarSlots || bikeSlots != _totalBikeSlots;
    if (capacityChanged) {
      bool? confirm = await _showConfirmationDialog("Capacity Change Detected",
          "Changing the total number of slots will reset all active bookings and available slots for this parking area (Hybrid Model reset). Are you sure you want to proceed?");
      if (confirm != true) {
        setState(() => _message = "Update cancelled by user.");
        return;
      }
    }

    try {
      setState(() => _isLoading = true);
      final response = await http.post(
        Uri.parse('$apiScheme://$apiHost/api/owner/parking_areas'),
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
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _message = data['message'] ?? 'Parking area updated successfully';
        });
        // Re-fetch details to ensure full sync with the backend
        _fetchParkingAreaDetails();
      } else {
        setState(() => _message = data['message'] ?? 'Failed to update');
        _showErrorDialog(data['message'] ?? 'Failed to update');
      }
    } catch (e) {
      print('Error updating parking area: $e');
      setState(() => _message = 'Error: $e');
      _showErrorDialog('Error: $e');
    }
  }

  Future<bool?> _showConfirmationDialog(String title, String content) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.poppins(color: errorRed)),
        content:
            Text(content, style: GoogleFonts.poppins(color: secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                Text("Cancel", style: GoogleFonts.poppins(color: primaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text("Confirm Reset",
                style: GoogleFonts.poppins(
                    color: errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
        iconTheme: const IconThemeData(
            color: primaryText), // Ensure back button is white
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
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _lngController,
                                label: "Longitude",
                                icon: Icons.location_on,
                                keyboardType: TextInputType.number,
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
                                    _message.contains('Invalid') ||
                                    _message.contains('Failed')
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
