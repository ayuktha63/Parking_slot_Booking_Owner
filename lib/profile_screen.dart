import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchParkingAreaDetails();
  }

  Future<void> _fetchParkingAreaDetails() async {
    setState(() => _isLoading = true);
    try {
      // First, fetch the owner's details to get the associated parking area name
      final userResponse = await http.post(
        Uri.parse('http://localhost:4000/api/owner/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phone,
        }),
      );
      final userData = jsonDecode(userResponse.body);
      final parkingAreaName = userData['parking_area_name'];

      if (parkingAreaName != null) {
        // Then, fetch the parking area details using the correct parking area name
        final parkingResponse = await http
            .get(Uri.parse('http://localhost:4000/api/owner/parking_areas'));
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
            _carSlotsController.text = parkingArea['total_car_slots'].toString();
            _bikeSlotsController.text = parkingArea['total_bike_slots'].toString();
            _totalCarSlots = parkingArea['total_car_slots'];
            _totalBikeSlots = parkingArea['total_bike_slots'];
            _message = 'Current parking area details loaded';
          } else {
            _message = 'Parking area profile not found. Please update.';
          }
        });
      } else {
        setState(() {
          _message = 'No parking area associated with this owner. Please update.';
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
        Uri.parse('http://localhost:4000/api/owner/parking_areas'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("Error"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xFF3F51B5))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Profile"),
        elevation: 0,
        backgroundColor: const Color(0xFF3F51B5),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF3F51B5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Parking Owner Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Phone: ${widget.phone}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),
                  if (_parkingAreaName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Parking Area: $_parkingAreaName",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF3F51B5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _updateParkingArea,
                      child: const Text(
                        "Update Parking Area",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _message,
                    style: TextStyle(
                      color: _message.contains('Error') ||
                          _message.contains('Invalid')
                          ? Colors.red
                          : Colors.green,
                      fontSize: 14,
                    ),
                  ),
                  if (_totalCarSlots != null &&
                      _totalBikeSlots != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
                              style: const TextStyle(fontSize: 16)),
                          Text('Total Bike Slots: $_totalBikeSlots',
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red[300],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _logout,
                      child: const Text(
                        "Logout",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
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
            color: const Color(0xFF3F51B5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF303030),
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
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF3F51B5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3F51B5)),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF3F51B5)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }
}
