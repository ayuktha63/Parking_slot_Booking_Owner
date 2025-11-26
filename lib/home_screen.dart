import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform; // Import for platform checks
import 'package:flutter/foundation.dart' show kIsWeb; // Import for web check
import 'profile_screen.dart';
import 'success_screen.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO; // ✅ NEW

// --- DESIGN SYSTEM COLORS (Dark Mode) ---
const Color appBackground = Color(0xFF1C1C1E);
const Color cardSurface = Color(0xFF2C2C2E);
const Color appBarColor = Color(0xFF1C1C1E);
const Color infoItemBg = Color(0xFF3A3A3C);
const Color primaryText = Color(0xFFFFFFFF);
const Color secondaryText = Color(0xFFB0B0B5);
const Color hintText = Color(0xFF8E8E93);
const Color darkText = Color(0xFF000000);
const Color markerColor = Color(0xFF0A84FF); // Blue Accent for active state
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
  String apiHost = 'backend-parking-bk8y.onrender.com';
  String apiScheme = 'https';

  Razorpay? _razorpay;
  IO.Socket? socket; // ✅ NEW
  String _vehicleType = 'car';
  List<dynamic> _slots = [];
  int? _parkingId;

  bool _isLoading = true;

  int _totalCarSlots = 0;
  int _availableCarSlots = 0;
  int _bookedCarSlots = 0;

  int _totalBikeSlots = 0;
  int _availableBikeSlots = 0;
  int _bookedBikeSlots = 0;

  // State to hold data for booking completion after successful payment
  Map<String, dynamic>? _pendingCompletionData;

  @override
  void initState() {
    super.initState();
    // Host setup
    if (kIsWeb &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
      apiHost = '127.0.0.1:3000';
      apiScheme = 'http';
    }

    _fetchSlots();
    _initSocket(); // ✅ NEW
    // Initialize Razorpay only on Android and iOS.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  void _initSocket() {
    socket = IO.io(
      '$apiScheme://$apiHost',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    socket!.onConnect((_) {
      print("✅ SOCKET CONNECTED");

      if (_parkingId != null) {
        socket!.emit("join_parking", {
          "parking_id": _parkingId,
          "vehicle_type": _vehicleType.toLowerCase(), // ✅ IMPORTANT
        });
      }
    });

    socket!.on("slot_update", (data) {
      print("📡 SLOT UPDATE: $data");

      if (!mounted) return;

      if (_parkingId == data["parking_id"] &&
          _vehicleType == data["vehicle_type"]) {
        setState(() {
          _slots = _slots.map((slot) {
            if (slot['slot_number'] == data['slot_number'] &&
                slot['vehicle_type'] == data['vehicle_type']) {
              return {
                ...slot,
                "status": data['status'], // ✅ NEW field instead of is_booked
              };
            }
            return slot;
          }).toList();
        });
      }
    });

    socket!.onDisconnect((_) => print("❌ SOCKET DISCONNECTED"));
  }

  @override
  void dispose() {
    socket?.disconnect(); // ✅ NEW
    socket?.destroy(); // ✅ NEW
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoading = true);
    try {
      final parkingResponse = await http
          .get(Uri.parse('$apiScheme://$apiHost/api/owner/parking_areas'));
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

      final parkingId = parkingArea['id'];

      // Fetch slots for the current vehicle type
      final slotsResponse = await http.get(
        Uri.parse(
            '$apiScheme://$apiHost/api/owner/parking_areas/$parkingId/slots?vehicle_type=$_vehicleType'),
      );
      final slots = jsonDecode(slotsResponse.body);

      // Fetch ALL car and bike slots to get accurate counts (Hybrid Model)
      final allCarSlotsResponse = await http.get(Uri.parse(
          '$apiScheme://$apiHost/api/owner/parking_areas/$parkingId/slots?vehicle_type=car'));
      final allBikeSlotsResponse = await http.get(Uri.parse(
          '$apiScheme://$apiHost/api/owner/parking_areas/$parkingId/slots?vehicle_type=bike'));

      final allCarSlots = jsonDecode(allCarSlotsResponse.body);
      final allBikeSlots = jsonDecode(allBikeSlotsResponse.body);

      setState(() {
        _slots = slots;
        _parkingId = parkingId;

// ✅ Join socket room
        if (socket != null) {
          socket!.emit("join_parking", {
            "parking_id": parkingId,
            "vehicle_type": _vehicleType.toLowerCase(), // ✅ FIX
          });
        }

        _isLoading = false;

        _totalCarSlots = parkingArea['total_car_slots'] ?? 0;
        _availableCarSlots =
            allCarSlots.where((s) => s['status'] == "available").length;
        _bookedCarSlots =
            allCarSlots.where((s) => s['status'] == "booked").length;

        _totalBikeSlots = parkingArea['total_bike_slots'] ?? 0;
        _availableBikeSlots =
            allBikeSlots.where((s) => s['status'] == "available").length;
        _bookedBikeSlots =
            allBikeSlots.where((s) => s['status'] == "booked").length;
      });
    } catch (e) {
      print('Error fetching slots: $e');
      _showErrorDialog('Error connecting to server. Please check host.');
      setState(() {
        _slots = [];
        _isLoading = false;
      });
    }
  }

  // Helper to open Razorpay checkout (simplified)
  void _openCheckout(int amountInPaise) async {
    if (_razorpay == null) {
      _showErrorDialog("Payment is only supported on Android and iOS devices.");
      return;
    }

    final options = <String, Object>{
      'key': RAZORPAY_KEY,
      'amount': amountInPaise,
      'name': 'Parking Area Owner App',
      'description': 'Parking Exit Fee',
      'prefill': {'contact': widget.phone, 'email': 'owner@example.com'},
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      _showErrorDialog("Error opening Razorpay checkout: $e");
    }
  }

  // New centralized function to complete the booking on the backend (Option B)
  Future<void> _completeBookingOwner(
      Map<String, dynamic> data, String? paymentId) async {
    // Show progress dialog while completing
    Navigator.pop(context); // Close the details dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: primaryText)),
    );

    try {
      final completeResponse = await http.post(
        Uri.parse('$apiScheme://$apiHost/api/owner/bookings/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          // CRITICAL: Send booking_id (the active record's _id)
          'booking_id': data['booking_id'],
          'parking_id': data['parking_id'],
          'vehicle_type': data['vehicle_type'],
          'exit_time': data['exit_time'],
          'amount': data['amount'],
          'payment_id': paymentId,
        }),
      );

      if (mounted) Navigator.pop(context); // Close progress dialog

      if (completeResponse.statusCode == 200) {
        final successReceipt = {
          // We have the minimal info needed for a simple success receipt
          'slot_number': data['slot_number'],
          'vehicle_number': data['vehicle_number'],
          'entry_time': data['entry_time'],
          'exit_time': data['exit_time'],
          'amount': data['amount'],
          'parking_name': widget.parkingAreaName,
        };

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SuccessScreen(receipt: successReceipt),
            ),
          ).then((_) => _fetchSlots());
        }
      } else {
        _showErrorDialog(
            'Failed to complete booking: ${jsonDecode(completeResponse.body)['message'] ?? completeResponse.body}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close progress dialog
      print('Error completing booking: $e');
      _showErrorDialog('Error completing booking: $e');
    }
  }

  // --- UPDATED PAYMENT HANDLERS ---
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingCompletionData == null) {
      _showErrorDialog(
          "Payment succeeded but booking context was lost. Cannot complete booking.");
      return;
    }

    // Use the stored context to call the completion API
    await _completeBookingOwner(_pendingCompletionData!, response.paymentId);

    _pendingCompletionData = null; // Clear state
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showErrorDialog("ERROR: ${response.code} - ${response.message}");
    _pendingCompletionData = null; // Clear state on failure
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showErrorDialog("EXTERNAL WALLET: ${response.walletName}");
    _pendingCompletionData = null; // Clear state
  }

  // New function to handle the pay button press.
  void _onPayButtonPressed(
      dynamic booking, int? calculatedAmount, DateTime exitTime) {
    // 1. Prepare completion data and store it in state
    _pendingCompletionData = {
      'booking_id': booking['id'],
      'parking_id': booking['parking_id'],
      'slot_number': booking['slot_number'],
      'vehicle_type': booking['vehicle_type'],
      'vehicle_number': booking['number_plate'], // For receipt purposes
      'entry_time': booking['entry_time'],
      'exit_time': exitTime.toIso8601String(),
      'amount': calculatedAmount,
    };

    // 2. Start Razorpay checkout
    _openCheckout((calculatedAmount ?? 0) * 100); // Amount must be in paise
  }
  // --- END UPDATED PAYMENT HANDLERS ---

  // --- UPDATED SLOT DETAIL FETCH ---
  void _showBookedDetails(dynamic slot) async {
    if (_parkingId == null) return;

    // 1. Fetch active booking details using new query parameters
    try {
      final bookingResponse = await http.get(
        Uri.parse(
            '$apiScheme://$apiHost/api/owner/bookings?parking_id=$_parkingId&slot_number=${slot['slot_number']}&vehicle_type=${slot['vehicle_type']}'),
      );

      if (bookingResponse.statusCode != 200) {
        _showErrorDialog('No active booking found for this slot.');
        return;
      }

      final booking =
          jsonDecode(bookingResponse.body); // Single active booking object

      int? calculatedAmount;
      DateTime entryTime = DateTime.parse(booking['entry_time']);
      DateTime exitTime = DateTime.now();

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: cardSurface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: markerColor),
                const SizedBox(width: 8),
                Text(
                  "Slot Details (Slot ${slot['slot_number']})",
                  style: GoogleFonts.poppins(color: primaryText),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone: ${booking['phone']}',
                    style: GoogleFonts.poppins(color: secondaryText)),
                Text('Vehicle Number: ${booking['number_plate']}',
                    style: GoogleFonts.poppins(color: secondaryText)),
                Text(
                    'Entry Time: ${DateFormat('MMM dd, hh:mm a').format(entryTime)}',
                    style: GoogleFonts.poppins(color: secondaryText)),
                if (calculatedAmount != null) ...[
                  const Divider(color: hintText, height: 20),
                  Text('Calculated Amount (Seconds): ₹$calculatedAmount',
                      style: GoogleFonts.poppins(
                          color: primaryText, fontWeight: FontWeight.bold)),
                ]
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Simple calculation logic for demo (1 rupee per second)
                  exitTime = DateTime.now();
                  int secondsDifference =
                      exitTime.difference(entryTime).inSeconds;
                  setStateDialog(() {
                    calculatedAmount = secondsDifference;
                  });
                },
                child: Text('Calculate Now',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: primaryText)),
              ),
              if (calculatedAmount != null)
                TextButton(
                  onPressed: () {
                    // Pass the whole booking object and calculated amount
                    _onPayButtonPressed(booking, calculatedAmount, exitTime);
                    // Close dialog to allow payment gateway to open
                    Navigator.pop(context);
                  },
                  child: Text('Pay with Razorpay',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: primaryText)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: primaryText)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error fetching active booking details: $e');
      _showErrorDialog('Error fetching slot details: $e');
    }
  }
  // --- END UPDATED SLOT DETAIL FETCH ---

  // --- UPDATED MANUAL BOOKING ---
// --- UPDATED MANUAL BOOKING WITH HOLD FIRST ---
  void _bookSlot(dynamic slot) async {
    if (_parkingId == null) return;

    // ✅ 1. Create HOLD instantly when owner taps slot
    try {
      final holdResponse = await http.post(
        Uri.parse('$apiScheme://$apiHost/api/holds'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'parking_id': _parkingId,
          'slot_number': slot['slot_number'],
          'vehicle_type': _vehicleType,
          'phone': widget.phone, // optional
        }),
      );

      if (holdResponse.statusCode != 200) {
        final msg = jsonDecode(holdResponse.body)['message'] ?? "Hold failed";
        _showErrorDialog(msg);
        return;
      }
    } catch (e) {
      print("Hold error: $e");
      _showErrorDialog("Unable to hold slot. Try again.");
      return;
    }

    // ✅ 2. Continue with Number Plate Popup
    showDialog(
      context: context,
      builder: (context) {
        final vehicleNumberController = TextEditingController();
        return AlertDialog(
          backgroundColor: cardSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.directions_car, color: markerColor),
              const SizedBox(width: 8),
              Text("Book Slot ${slot['slot_number']}",
                  style: GoogleFonts.poppins(color: primaryText)),
            ],
          ),
          content: TextField(
            controller: vehicleNumberController,
            style: GoogleFonts.poppins(color: primaryText),
            decoration: InputDecoration(
              labelText: _vehicleType == 'car'
                  ? 'Car Number Plate'
                  : 'Bike Number Plate',
              labelStyle: GoogleFonts.poppins(color: hintText),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: infoItemBg,
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
                    Uri.parse('$apiScheme://$apiHost/api/owner/bookings'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'parking_id': _parkingId,
                      'slot_number': slot['slot_number'],
                      'vehicle_type': _vehicleType,
                      'number_plate':
                          vehicleNumberController.text.toUpperCase(),
                      'entry_time': DateTime.now().toIso8601String(),
                      'phone': widget.phone,
                    }),
                  );

                  if (response.statusCode == 200) {
                    if (mounted) {
                      Navigator.pop(context);
                      _showErrorDialog("Manual Booking Successful!");
                      _fetchSlots(); // Refresh slot status
                    }
                  } else {
                    _showErrorDialog(jsonDecode(response.body)['message'] ??
                        "Booking failed");
                  }
                } catch (e) {
                  print('Error booking slot: $e');
                  _showErrorDialog('Error booking slot: $e');
                }
              },
              child: Text('Book Now',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: primaryText)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: primaryText)),
            ),
          ],
        );
      },
    );
  }

  // --- END UPDATED MANUAL BOOKING ---

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: errorRed),
            const SizedBox(width: 8),
            Text("Error", style: GoogleFonts.poppins(color: primaryText)),
          ],
        ),
        content:
            Text(message, style: GoogleFonts.poppins(color: secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: primaryText)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        title: Text(
          widget.parkingAreaName,
          style: GoogleFonts.poppins(color: primaryText),
        ),
        elevation: 0,
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: primaryText), // Make back button white
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: primaryText),
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
                color: appBarColor,
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
                      color: primaryText,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Manage your parking slots",
                    style: GoogleFonts.poppins(
                      color: secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSlotCount(Icons.directions_car, "Cars",
                            _availableCarSlots, _bookedCarSlots),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSlotCount(Icons.motorcycle, "Bikes",
                            _availableBikeSlots, _bookedBikeSlots),
                      ),
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
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: shadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: "Select Vehicle Type",
                        labelStyle: GoogleFonts.poppins(color: hintText),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 0),
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
                        fillColor: infoItemBg,
                      ),
                      style: GoogleFonts.poppins(color: primaryText),
                      value: _vehicleType,
                      items: [
                        DropdownMenuItem(
                            value: 'car',
                            child: Text('Car',
                                style:
                                    GoogleFonts.poppins(color: primaryText))),
                        DropdownMenuItem(
                            value: 'bike',
                            child: Text('Bike',
                                style:
                                    GoogleFonts.poppins(color: primaryText))),
                      ],
                      onChanged: (value) {
                        setState(() => _vehicleType = value!);

                        if (_parkingId != null && socket != null) {
                          socket!.emit("join_parking", {
                            "parking_id": _parkingId,
                            "vehicle_type": value?.toLowerCase(), // ✅ FIX
                          });
                        }

                        _fetchSlots();
                      },
                      dropdownColor: cardSurface,
                      icon: const Icon(Icons.arrow_drop_down, color: hintText),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Parking Slots"),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
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
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildLegendItem(
                                const Color(0xFF4CAF50), "Available"),
                            _buildLegendItem(Colors.orangeAccent, "Held"),
                            _buildLegendItem(errorRed, "Booked"),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                color: markerColor,
                              ))
                            : _slots.isEmpty
                                ? Center(
                                    child: Text(
                                    "No slots available. Update parking area in Profile.",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                        color: secondaryText),
                                  ))
                                : Wrap(
                                    spacing: 10.0,
                                    runSpacing: 10.0,
                                    children: _slots.map((slot) {
                                      final slotNumber = slot['slot_number'];
                                      final String status =
                                          slot['status'] ?? "available";
                                      final bool isBooked = status == "booked";
                                      final bool isHeld = status == "held";

                                      return GestureDetector(
                                        onTap: () {
                                          if (isBooked) {
                                            _showBookedDetails(slot);
                                          } else if (isHeld) {
                                            _showErrorDialog(
                                                "This slot is temporarily held by a user.");
                                          } else {
                                            _bookSlot(slot);
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          width: 65,
                                          height: 65,
                                          decoration: BoxDecoration(
                                            color: isBooked
                                                ? errorRed // 🔴 booked
                                                : isHeld
                                                    ? Colors
                                                        .orangeAccent // 🟡 held
                                                    : const Color(
                                                        0xFF4CAF50), // ✅ available

                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: !isBooked
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF4CAF50)
                                                          .withOpacity(0.3),
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
            color: markerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
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
          style: GoogleFonts.poppins(fontSize: 12, color: secondaryText),
        ),
      ],
    );
  }

  Widget _buildSlotCount(
      IconData icon, String label, int available, int booked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$available / ${available + booked}",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "$label (Avail/Total)",
                  style:
                      GoogleFonts.poppins(fontSize: 12, color: secondaryText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
