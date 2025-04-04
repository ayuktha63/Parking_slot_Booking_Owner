import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_screen.dart';
import 'success_screen.dart';

class HomeScreen extends StatefulWidget {
  final String phone;
  final String parkingAreaName;

  const HomeScreen(
      {super.key, required this.phone, required this.parkingAreaName});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _vehicleType = 'car';
  List<dynamic> _slots = [];
  int _totalSlots = 0;
  int _availableSlots = 0;
  int _bookedSlots = 0;
  String? _parkingId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSlots();
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoading = true);
    try {
      final parkingResponse = await http
          .get(Uri.parse('http://localhost:4000/api/owner/parking_areas'));
      final parkingAreas = jsonDecode(parkingResponse.body);
      final parkingArea = parkingAreas.firstWhere(
        (area) => area['name'] == widget.phone,
        orElse: () => null,
      );

      if (parkingArea == null) {
        setState(() {
          _slots = [];
          _totalSlots = 0;
          _availableSlots = 0;
          _bookedSlots = 0;
          _parkingId = null;
          _isLoading = false;
        });
        return;
      }

      final parkingId = parkingArea['_id'];
      final slotsResponse = await http.get(
        Uri.parse(
            'http://localhost:4000/api/owner/parking_areas/$parkingId/slots?vehicle_type=$_vehicleType'),
      );
      final slots = jsonDecode(slotsResponse.body);

      setState(() {
        _slots = slots;
        _totalSlots = _vehicleType == 'car'
            ? parkingArea['total_car_slots']
            : parkingArea['total_bike_slots'];
        _availableSlots = slots.where((slot) => !slot['is_booked']).length;
        _bookedSlots = _totalSlots - _availableSlots;
        _parkingId = parkingId;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching slots: $e');
      setState(() {
        _slots = [];
        _totalSlots = 0;
        _availableSlots = 0;
        _bookedSlots = 0;
        _isLoading = false;
      });
    }
  }

  void _showBookedDetails(dynamic slot) async {
    try {
      final bookingResponse = await http.get(
        Uri.parse(
            'http://localhost:4000/api/owner/bookings?slot_id=${slot['_id']}'),
      );
      final bookings = jsonDecode(bookingResponse.body);
      if (bookings.isEmpty) return;

      final booking = bookings.firstWhere(
        (b) => b['slot_id'] == slot['_id'] && b['status'] == 'active',
        orElse: () => null,
      );

      if (booking != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF3F51B5)),
                SizedBox(width: 8),
                Text("Slot Details"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone: ${booking['phone']}'),
                Text('Vehicle Number: ${booking['number_plate']}'),
                Text('Entry Time: ${booking['entry_time']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close',
                    style: TextStyle(color: Color(0xFF3F51B5))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error fetching booking details: $e');
      _showErrorDialog('Error fetching slot details: $e');
    }
  }

  void _bookSlot(dynamic slot) {
    showDialog(
      context: context,
      builder: (context) {
        final vehicleNumberController = TextEditingController();
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.directions_car, color: Color(0xFF3F51B5)),
              SizedBox(width: 8),
              Text("Book Slot"),
            ],
          ),
          content: TextField(
            controller: vehicleNumberController,
            decoration: InputDecoration(
              labelText: _vehicleType == 'car'
                  ? 'Car Number Plate'
                  : 'Bike Number Plate',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(
                  _vehicleType == 'car'
                      ? Icons.directions_car
                      : Icons.motorcycle,
                  color: const Color(0xFF3F51B5)),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  final response = await http.post(
                    Uri.parse('http://localhost:4000/api/owner/bookings'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'parking_id': slot['parking_id'],
                      'slot_id': slot['_id'],
                      'vehicle_type': _vehicleType,
                      'number_plate': vehicleNumberController.text,
                      'entry_time': DateTime.now().toIso8601String(),
                      'phone': widget.phone,
                    }),
                  );

                  if (response.statusCode == 200) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SuccessScreen(
                          receipt: {
                            'slot_number': slot['slot_number'],
                            'vehicle_number': vehicleNumberController.text,
                            'entry_time': DateTime.now().toIso8601String(),
                          },
                        ),
                      ),
                    ).then((_) => _fetchSlots());
                  } else {
                    _showErrorDialog('Failed to book slot: ${response.body}');
                  }
                } catch (e) {
                  print('Error booking slot: $e');
                  _showErrorDialog('Error booking slot: $e');
                }
              },
              child: const Text('Book',
                  style: TextStyle(color: Color(0xFF3F51B5))),
            ),
          ],
        );
      },
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
        title: Text(widget.parkingAreaName),
        elevation: 0,
        backgroundColor: const Color(0xFF3F51B5),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ProfileScreen(phone: widget.phone)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                  Text(
                    widget.parkingAreaName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Manage your parking slots",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSlotCount(Icons.directions_car, "Cars",
                          _availableSlots, _bookedSlots),
                      _buildSlotCount(Icons.motorcycle, "Bikes",
                          _availableSlots, _bookedSlots),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Vehicle Type"),
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
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: "Select Vehicle Type",
                        labelStyle: const TextStyle(color: Color(0xFF3F51B5)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF3F51B5)),
                        ),
                        prefixIcon: const Icon(Icons.directions_car,
                            color: Color(0xFF3F51B5)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      value: _vehicleType,
                      items: const [
                        DropdownMenuItem(value: 'car', child: Text('Car')),
                        DropdownMenuItem(value: 'bike', child: Text('Bike')),
                      ],
                      onChanged: (value) {
                        setState(() => _vehicleType = value!);
                        _fetchSlots();
                      },
                      dropdownColor: Colors.white,
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Color(0xFF3F51B5)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Parking Slots"),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLegendItem(Colors.grey[300]!, "Available"),
                            _buildLegendItem(
                                const Color(0xFF4CAF50), "Available"),
                            _buildLegendItem(Colors.red[300]!, "Booked"),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _slots.isEmpty
                                ? const Center(
                                    child: Text(
                                        "No slots available. Update parking area in Profile."))
                                : Wrap(
                                    spacing: 10.0,
                                    runSpacing: 10.0,
                                    children: _slots.map((slot) {
                                      final slotId = slot['_id'];
                                      final slotNumber = slot['slot_number'];
                                      final isBooked =
                                          slot['is_booked'] == true;

                                      return GestureDetector(
                                        onTap: () => isBooked
                                            ? _showBookedDetails(slot)
                                            : _bookSlot(slot),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          width: 65,
                                          height: 65,
                                          decoration: BoxDecoration(
                                            color: isBooked
                                                ? Colors.red[300]
                                                : const Color(0xFF4CAF50),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: !isBooked
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF4CAF50)
                                                          .withOpacity(0.4),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 2),
                                                    )
                                                  ]
                                                : [],
                                          ),
                                          child: Center(
                                            child: Text(
                                              "$slotNumber",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                      ],
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSlotCount(
      IconData icon, String label, int available, int booked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$available / ${available + booked}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "$label (Avail/Total)",
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
