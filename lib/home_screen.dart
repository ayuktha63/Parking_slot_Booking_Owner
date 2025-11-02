import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform; // Import for platform checks
import 'package:flutter/foundation.dart' show kIsWeb; // Import for web check
import 'profile_screen.dart';
import 'success_screen.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

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

class HomeScreen extends StatefulWidget {
  final String phone;
  final String parkingAreaName;

  const HomeScreen(
      {super.key, required this.phone, required this.parkingAreaName});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String RAZORPAY_KEY = 'rzp_live_R6QQALUuJwgDaD';
  String apiHost = 'localhost';

  Razorpay? _razorpay; // Made nullable
  String _vehicleType = 'car';
  List<dynamic> _slots = [];
  String? _parkingId;
  bool _isLoading = true;

  int _totalCarSlots = 0;
  int _availableCarSlots = 0;
  int _bookedCarSlots = 0;

  int _totalBikeSlots = 0;
  int _availableBikeSlots = 0;
  int _bookedBikeSlots = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      apiHost = '127.0.0.1';
    } else {
      apiHost = '10.0.2.2';
    }

    _fetchSlots();
    // Initialize Razorpay only on Android and iOS.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoading = true);
    try {
      final parkingResponse = await http
          .get(Uri.parse('http://$apiHost:4000/api/owner/parking_areas'));
      final parkingAreas = jsonDecode(parkingResponse.body);
      final parkingArea = parkingAreas.firstWhere(
        (area) => area['name'] == widget.parkingAreaName,
        orElse: () => null,
      );

      if (parkingArea == null) {
        setState(() {
          _slots = [];
          _parkingId = null;
          _isLoading = false;
        });
        return;
      }

      final parkingId = parkingArea['_id'];
      final slotsResponse = await http.get(
        Uri.parse(
            'http://$apiHost:4000/api/owner/parking_areas/$parkingId/slots?vehicle_type=$_vehicleType'),
      );
      final slots = jsonDecode(slotsResponse.body);

      final allCarSlotsResponse = await http.get(Uri.parse(
          'http://$apiHost:4000/api/owner/parking_areas/$parkingId/slots?vehicle_type=car'));
      final allBikeSlotsResponse = await http.get(Uri.parse(
          'http://$apiHost:4000/api/owner/parking_areas/$parkingId/slots?vehicle_type=bike'));

      final allCarSlots = jsonDecode(allCarSlotsResponse.body);
      final allBikeSlots = jsonDecode(allBikeSlotsResponse.body);

      setState(() {
        _slots = slots;
        _parkingId = parkingId;
        _isLoading = false;

        _totalCarSlots = parkingArea['total_car_slots'];
        _availableCarSlots = allCarSlots.where((s) => !s['is_booked']).length;
        _bookedCarSlots = _totalCarSlots - _availableCarSlots;

        _totalBikeSlots = parkingArea['total_bike_slots'];
        _availableBikeSlots = allBikeSlots.where((s) => !s['is_booked']).length;
        _bookedBikeSlots = _totalBikeSlots - _availableBikeSlots;
      });
    } catch (e) {
      print('Error fetching slots: $e');
      setState(() {
        _slots = [];
        _isLoading = false;
      });
    }
  }

  void _openCheckout(
      int amountInPaise, Map<String, dynamic> bookingDetails) async {
    // Check if Razorpay is supported before trying to open it
    if (_razorpay == null) {
      _showErrorDialog("Payment is only supported on Android and iOS devices.");
      return;
    }

    final options = <String, Object>{
      'key': RAZORPAY_KEY,
      'amount': 100, // Hardcoded to 1 rupee (100 paise)
      'name': 'Parking Area Owner App',
      'description': 'Payment for Parking Slot',
      'prefill': {'contact': widget.phone, 'email': 'owner@example.com'},
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      _showErrorDialog("Error opening Razorpay checkout: $e");
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    _showErrorDialog("SUCCESS: ${response.paymentId}");

    // Hardcoded booking details for testing
    final Map<String, dynamic> booking = {
      'slot_id': _slots.firstWhere((s) => s['is_booked'])['_id'],
      'parking_id': _parkingId,
      'vehicle_type': _vehicleType,
      'exit_time': DateTime.now().toIso8601String(),
      'amount': 1,
    };

    try {
      final completeResponse = await http.post(
        Uri.parse('http://$apiHost:4000/api/owner/bookings/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'slot_id': booking['slot_id'],
          'parking_id': booking['parking_id'],
          'vehicle_type': booking['vehicle_type'],
          'exit_time': booking['exit_time'],
          'amount': booking['amount'],
        }),
      );

      if (completeResponse.statusCode == 200) {
        final successReceipt = {
          ...booking,
          'slot_number':
              _slots.firstWhere((s) => s['is_booked'])['slot_number'],
          'vehicle_number': "TEST-1234",
          'entry_time': "TEST ENTRY TIME",
          'date': DateTime.now().toIso8601String().split('T')[0],
          'parking_name': widget.parkingAreaName,
        };
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessScreen(receipt: successReceipt),
          ),
        ).then((_) => _fetchSlots());
      } else {
        _showErrorDialog(
            'Failed to complete booking: ${completeResponse.body}');
      }
    } catch (e) {
      print('Error completing booking: $e');
      _showErrorDialog('Error completing booking: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showErrorDialog("ERROR: ${response.code} - ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showErrorDialog("EXTERNAL WALLET: ${response.walletName}");
  }

  void _showBookedDetails(dynamic slot) async {
    try {
      final bookingResponse = await http.get(
        Uri.parse(
            'http://$apiHost:4000/api/owner/bookings?slot_id=${slot['_id']}'),
      );
      final bookings = jsonDecode(bookingResponse.body);
      if (bookings.isEmpty) return;

      final booking = bookings.firstWhere(
        (b) => b['slot_id'] == slot['_id'] && b['status'] == 'active',
        orElse: () => null,
      );

      if (booking != null) {
        int? calculatedAmount;
        DateTime exitTime = DateTime.now();

        showDialog(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              backgroundColor: cardSurface, // New Color
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: markerColor), // New Color
                  const SizedBox(width: 8),
                  Text(
                    "Slot Details",
                    style: GoogleFonts.poppins(color: primaryText), // New Style
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Phone: ${booking['phone']}',
                      style: GoogleFonts.poppins(
                          color: secondaryText)), // New Style
                  Text('Vehicle Number: ${booking['number_plate']}',
                      style: GoogleFonts.poppins(
                          color: secondaryText)), // New Style
                  Text('Entry Time: ${booking['entry_time']}',
                      style: GoogleFonts.poppins(
                          color: secondaryText)), // New Style
                  if (calculatedAmount != null)
                    Text('Amount: ₹$calculatedAmount',
                        style: GoogleFonts.poppins(
                            color: primaryText,
                            fontWeight: FontWeight.bold)), // New Style
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    DateTime entryTime = DateTime.parse(booking['entry_time']);
                    exitTime = DateTime.now();
                    int secondsDifference =
                        exitTime.difference(entryTime).inSeconds;
                    setStateDialog(() {
                      calculatedAmount = secondsDifference;
                    });
                  },
                  child: Text('Calculate Now',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: primaryText)), // New Style
                ),
                if (calculatedAmount != null)
                  TextButton(
                    onPressed: () {
                      _onPayButtonPressed(slot, calculatedAmount, exitTime);
                    },
                    child: Text('Pay with Razorpay',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: primaryText)), // New Style
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: primaryText)), // New Style
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      print('Error fetching booking details: $e');
      _showErrorDialog('Error fetching slot details: $e');
    }
  }

  // New function to handle the pay button press.
  void _onPayButtonPressed(
      dynamic slot, int? calculatedAmount, DateTime exitTime) {
    _openCheckout(100, {
      'slot_id': slot['_id'],
      'parking_id': slot['parking_id'],
      'vehicle_type': _vehicleType,
      'exit_time': exitTime.toIso8601String(),
      'amount': calculatedAmount,
    });
  }

  void _bookSlot(dynamic slot) {
    showDialog(
      context: context,
      builder: (context) {
        final vehicleNumberController = TextEditingController();
        return AlertDialog(
          backgroundColor: cardSurface, // New Color
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.directions_car, color: markerColor), // New Color
              const SizedBox(width: 8),
              Text("Book Slot",
                  style: GoogleFonts.poppins(color: primaryText)), // New Style
            ],
          ),
          content: TextField(
            controller: vehicleNumberController,
            style: GoogleFonts.poppins(color: primaryText), // New Style
            decoration: InputDecoration(
              labelText: _vehicleType == 'car'
                  ? 'Car Number Plate'
                  : 'Bike Number Plate',
              labelStyle: GoogleFonts.poppins(color: hintText), // New Style
              border: OutlineInputBorder(
                // New Style
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                // New Style
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                // New Style
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(
                  _vehicleType == 'car'
                      ? Icons.directions_car
                      : Icons.motorcycle,
                  color: hintText), // New Color
              filled: true,
              fillColor: infoItemBg, // New Color
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (vehicleNumberController.text.isEmpty) {
                  _showErrorDialog('Vehicle number plate is required.');
                  return;
                }
                try {
                  final response = await http.post(
                    Uri.parse('http://$apiHost:4000/api/owner/bookings'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'parking_id': _parkingId,
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
              child: Text('Book',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: primaryText)), // New Style
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
        title: Text(
          widget.parkingAreaName,
          style: GoogleFonts.poppins(color: primaryText), // New Style
        ),
        elevation: 0,
        backgroundColor: appBarColor, // New Color
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: primaryText), // New Color
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
                    widget.parkingAreaName,
                    style: GoogleFonts.poppins(
                      // New Style
                      color: primaryText,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Manage your parking slots",
                    style: GoogleFonts.poppins(
                      // New Style
                      color: secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSlotCount(Icons.directions_car, "Cars",
                          _availableCarSlots, _bookedCarSlots),
                      _buildSlotCount(Icons.motorcycle, "Bikes",
                          _availableBikeSlots, _bookedBikeSlots),
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
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        // New Style
                        labelText: "Select Vehicle Type",
                        labelStyle: GoogleFonts.poppins(color: hintText),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon:
                            const Icon(Icons.directions_car, color: hintText),
                        filled: true,
                        fillColor: infoItemBg, // New Color
                      ),
                      style:
                          GoogleFonts.poppins(color: primaryText), // New Style
                      value: _vehicleType,
                      items: [
                        DropdownMenuItem(
                            value: 'car',
                            child: Text('Car',
                                style: GoogleFonts.poppins(
                                    color: primaryText))), // New Style
                        DropdownMenuItem(
                            value: 'bike',
                            child: Text('Bike',
                                style: GoogleFonts.poppins(
                                    color: primaryText))), // New Style
                      ],
                      onChanged: (value) {
                        setState(() => _vehicleType = value!);
                        _fetchSlots();
                      },
                      dropdownColor: cardSurface, // New Color
                      icon: const Icon(Icons.arrow_drop_down,
                          color: hintText), // New Color
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Parking Slots"),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLegendItem(const Color(0xFF4CAF50),
                                "Available"), // Fixed Legend
                            _buildLegendItem(
                                errorRed, "Booked"), // Fixed Legend
                          ],
                        ),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                color: markerColor, // New Color
                              ))
                            : _slots.isEmpty
                                ? Center(
                                    child: Text(
                                    "No slots available. Update parking area in Profile.",
                                    style: GoogleFonts.poppins(
                                        color: secondaryText), // New Style
                                  ))
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
                                                ? errorRed // New Color
                                                : const Color(0xFF4CAF50),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: !isBooked
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF4CAF50)
                                                          .withOpacity(
                                                              0.3), // New Shadow
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
                                              style: GoogleFonts.poppins(
                                                // New Style
                                                color: primaryText,
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
          style: GoogleFonts.poppins(
              fontSize: 12, color: secondaryText), // New Style
        ),
      ],
    );
  }

  Widget _buildSlotCount(
      IconData icon, String label, int available, int booked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardSurface, // New Color
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryText), // New Color
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$available / ${available + booked}",
                style: GoogleFonts.poppins(
                  // New Style
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              Text(
                "$label (Avail/Total)",
                style: GoogleFonts.poppins(
                    // New Style
                    fontSize: 12,
                    color: secondaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
