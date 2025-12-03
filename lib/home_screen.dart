// HomeScreen.dart
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
import 'package:socket_io_client/socket_io_client.dart' as IO;

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

// Option A colors
const Color stateAvailable = Color(0xFF4CAF50);
const Color stateHeld = Colors.orangeAccent;
const Color statePending = Color(0xFF2196F3); // blueAccent
const Color stateBooked = errorRed;

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
  IO.Socket? socket;
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

  // pending completion data for owner exit payment flow
  Map<String, dynamic>? _pendingCompletionData;

  // local guard while verifying
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();

    // localhost handling for web
    if (kIsWeb &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
      apiHost = '127.0.0.1:3000';
      apiScheme = 'http';
    }

    _initSocket();
    _initRazorpayIfNeeded();
    // initial fetch
    _fetchSlots();
  }

  void _initRazorpayIfNeeded() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  void _initSocket() {
    try {
      socket = IO.io(
        '$apiScheme://$apiHost',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .build(),
      );

      socket!.onConnect((_) {
        debugPrint('✅ SOCKET CONNECTED');
        _joinSocketRoomIfReady();
      });

      socket!.on('slot_update', (data) {
        debugPrint('📡 slot_update -> $data');
        if (!mounted) return;

        // Only process if the payload is relevant to our parking + vehicle type
        try {
          final int pId = data['parking_id'] is int
              ? data['parking_id']
              : int.tryParse(data['parking_id'].toString()) ?? -1;
          final vType = (data['vehicle_type'] ?? '').toString().toLowerCase();

          if (_parkingId == null) return;
          if (pId != _parkingId) return;
          if (vType != _vehicleType) return;

          final int slotNumber = data['slot_number'] is int
              ? data['slot_number']
              : int.tryParse(data['slot_number'].toString()) ?? -1;
          final status = (data['status'] ?? 'available').toString();

          setState(() {
            _slots = _slots.map((slot) {
              if (slot['slot_number'] == slotNumber &&
                  slot['vehicle_type'] == vType) {
                // keep held_by for ownership display if provided
                return {
                  ...slot,
                  'status': status,
                  'held_by': data['phone'] ?? slot['held_by']
                };
              }
              return slot;
            }).toList();

            // update counts realtime (simple recompute)
            _recomputeCounts();
          });
        } catch (e) {
          debugPrint('Error processing slot_update: $e');
        }
      });

      socket!.onDisconnect((_) {
        debugPrint('❌ SOCKET DISCONNECTED');
      });
    } catch (e) {
      debugPrint('Socket init error: $e');
      socket = null;
    }
  }

  void _joinSocketRoomIfReady() {
    if (socket == null) return;
    if (_parkingId == null) return;
    socket!.emit('join_parking', {
      'parking_id': _parkingId,
      'vehicle_type': _vehicleType.toLowerCase(),
    });
    debugPrint('✅ join_parking emitted for ${_parkingId}_$_vehicleType');
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.destroy();
    _razorpay?.clear();
    super.dispose();
  }

  // -------------------- Fetch & helpers --------------------
  Future<void> _fetchSlots() async {
    setState(() => _isLoading = true);

    try {
      // 1) get owner's parking areas and pick one matching parkingAreaName
      final parkingResponse = await http
          .get(Uri.parse('$apiScheme://$apiHost/api/owner/parking_areas'));
      if (parkingResponse.statusCode != 200) {
        throw Exception('Failed to fetch parking areas');
      }
      final areas = jsonDecode(parkingResponse.body) as List<dynamic>;
      final area = areas.firstWhere(
        (a) => a['name'] == widget.parkingAreaName,
        orElse: () => null,
      );

      if (area == null) {
        setState(() {
          _slots = [];
          _parkingId = null;
          _isLoading = false;
        });
        return;
      }

      final int parkingId =
          area['id'] is int ? area['id'] : int.parse(area['id'].toString());
      _parkingId = parkingId;

      // 2) fetch slots for selected vehicle type (for display)
      final slotsRes = await http.get(Uri.parse(
          '$apiScheme://$apiHost/api/owner/parking_areas/$parkingId/slots?vehicle_type=${_vehicleType.toLowerCase()}'));
      if (slotsRes.statusCode != 200) {
        throw Exception('Failed to fetch slots');
      }
      final slots = jsonDecode(slotsRes.body) as List<dynamic>;

      // 3) fetch slots for both vehicle types to recompute counts accurately
      final carRes = await http.get(Uri.parse(
          '$apiScheme://$apiHost/api/owner/parking_areas/$parkingId/slots?vehicle_type=car'));
      final bikeRes = await http.get(Uri.parse(
          '$apiScheme://$apiHost/api/owner/parking_areas/$parkingId/slots?vehicle_type=bike'));

      final carSlots = carRes.statusCode == 200
          ? jsonDecode(carRes.body) as List<dynamic>
          : <dynamic>[];
      final bikeSlots = bikeRes.statusCode == 200
          ? jsonDecode(bikeRes.body) as List<dynamic>
          : <dynamic>[];

      setState(() {
        _slots = slots.map((s) {
          // ensure shape: parking_id, slot_number, vehicle_type, status, held_by
          return {
            'parking_id': s['parking_id'] ?? parkingId,
            'slot_number': s['slot_number'],
            'vehicle_type': s['vehicle_type'],
            'status': s['status'] ?? 'available',
            'held_by': s['held_by'] ?? null,
          };
        }).toList();

        _totalCarSlots = area['total_car_slots'] ?? 0;
        _availableCarSlots =
            carSlots.where((s) => s['status'] == 'available').length;
        _bookedCarSlots = carSlots.where((s) => s['status'] == 'booked').length;

        _totalBikeSlots = area['total_bike_slots'] ?? 0;
        _availableBikeSlots =
            bikeSlots.where((s) => s['status'] == 'available').length;
        _bookedBikeSlots =
            bikeSlots.where((s) => s['status'] == 'booked').length;

        _isLoading = false;
      });

      // join socket room after parking id is known
      _joinSocketRoomIfReady();
    } catch (e) {
      debugPrint('Error fetching slots: $e');
      if (mounted) {
        _showErrorDialog('Error connecting to server. Please check host.');
        setState(() {
          _slots = [];
          _isLoading = false;
        });
      }
    }
  }

  void _recomputeCounts() {
    // recompute available/booked counts for current loaded slots (vehicle type)
    final current = _slots;
    final available = current.where((s) => s['status'] == 'available').length;
    final booked = current.where((s) => s['status'] == 'booked').length;
    // Set appropriate totals depending on vehicle type
    if (_vehicleType == 'car') {
      _availableCarSlots = available;
      _bookedCarSlots = booked;
    } else {
      _availableBikeSlots = available;
      _bookedBikeSlots = booked;
    }
  }

  // -------------------- Holds & Manual booking (owner) --------------------
  Future<bool> _createHold(int slotNumber) async {
    if (_parkingId == null) {
      _showErrorDialog('Parking not configured yet.');
      return false;
    }
    try {
      final res = await http.post(Uri.parse('$apiScheme://$apiHost/api/holds'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'parking_id': _parkingId,
            'slot_number': slotNumber,
            'vehicle_type': _vehicleType,
            'phone': widget.phone,
          }));
      if (res.statusCode == 200) {
        // optimistic update locally
        setState(() {
          _slots = _slots.map((s) {
            if (s['slot_number'] == slotNumber) {
              return {...s, 'status': 'held', 'held_by': widget.phone};
            }
            return s;
          }).toList();
          _recomputeCounts();
        });
        return true;
      } else {
        final body = res.body.isEmpty ? {} : jsonDecode(res.body);
        final msg = (body is Map && body['message'] != null)
            ? body['message']
            : 'Failed to create hold';
        _showErrorDialog(msg);
        return false;
      }
    } catch (e) {
      debugPrint('Hold error: $e');
      _showErrorDialog('Unable to hold slot. Try again.');
      return false;
    }
  }

  Future<void> _ownerCreateBooking(int slotNumber, String numberPlate) async {
    if (_parkingId == null) return;

    // show progress
    _showProgressDialog('Booking slot...');

    try {
      final res =
          await http.post(Uri.parse('$apiScheme://$apiHost/api/owner/bookings'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'parking_id': _parkingId,
                'slot_number': slotNumber,
                'vehicle_type': _vehicleType,
                'number_plate': numberPlate,
                // FIXED: Send UTC time to ensure server consistency
                'entry_time': DateTime.now().toUtc().toIso8601String(),
                'phone': widget.phone,
              }));

      Navigator.pop(context); // hide progress

      if (res.statusCode == 200) {
        _showInfoDialog('Manual Booking Successful!');
        await _fetchSlots();
      } else {
        final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
        final msg = (body is Map && body['message'] != null)
            ? body['message']
            : 'Booking failed';
        _showErrorDialog(msg);
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint('Error booking slot: $e');
      _showErrorDialog('Error booking slot: $e');
    }
  }

  // --- when owner taps an available slot we:
  // 1) create hold, 2) show number plate popup -> call owner booking
  void _bookSlot(dynamic slot) async {
    final slotNumber = slot['slot_number'] as int;
    final status = (slot['status'] ?? 'available').toString();

    if (status == 'held') {
      _showErrorDialog('This slot is temporarily held by a user.');
      return;
    }
    if (status == 'pending' || status == 'booked') {
      _showBookedDetails(slot);
      return;
    }

    // create hold first
    final ok = await _createHold(slotNumber);
    if (!ok) return;

    // show number plate dialog
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
              Text("Book Slot $slotNumber",
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
                if (vehicleNumberController.text.trim().isEmpty) {
                  _showErrorDialog('Vehicle number plate is required.');
                  return;
                }
                Navigator.pop(context); // close dialog
                await _ownerCreateBooking(slotNumber,
                    vehicleNumberController.text.trim().toUpperCase());
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

  // -------------------- Booked slot details and complete flow --------------------
  Future<void> _showBookedDetails(dynamic slot) async {
    if (_parkingId == null) return;
    try {
      final resp = await http.get(Uri.parse(
          '$apiScheme://$apiHost/api/owner/bookings?parking_id=${_parkingId}&slot_number=${slot['slot_number']}&vehicle_type=${slot['vehicle_type']}'));
      if (resp.statusCode != 200) {
        _showErrorDialog('No active booking found for this slot.');
        return;
      }

      final booking = jsonDecode(resp.body) as Map<String, dynamic>;

      int? calculatedAmount;
      DateTime entryTime = DateTime.parse(booking['entry_time']);
      DateTime exitTime = DateTime.now();

      // booking may include is_verified flag from backend
      final bool isVerified = booking['is_verified'] == true;
      final String status = (slot['status'] ?? 'available').toString();

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
                Text('Slot Details (Slot ${slot['slot_number']})',
                    style: GoogleFonts.poppins(color: primaryText)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone: ${booking['phone'] ?? '-'}',
                    style: GoogleFonts.poppins(color: secondaryText)),
                Text('Vehicle Number: ${booking['number_plate'] ?? '-'}',
                    style: GoogleFonts.poppins(color: secondaryText)),
                Text(
                    'Entry Time: ${DateFormat('MMM dd, hh:mm a').format(entryTime)}',
                    style: GoogleFonts.poppins(color: secondaryText)),
                const SizedBox(height: 8),
                // show verification status explicitly
                Text(
                  isVerified
                      ? 'Status: Verified (Booked)'
                      : 'Status: Pending (Unverified)',
                  style: GoogleFonts.poppins(
                    color: isVerified ? stateBooked : statePending,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (calculatedAmount != null) ...[
                  const Divider(color: hintText, height: 20),
                  Text('Calculated Amount (₹): ₹$calculatedAmount',
                      style: GoogleFonts.poppins(
                          color: primaryText, fontWeight: FontWeight.bold)),
                ]
              ],
            ),
            actions: [
              // 1) VERIFY BOOKING button (only when pending & not verified)
              if (!isVerified)
                TextButton(
                  onPressed: _isVerifying
                      ? null
                      : () async {
                          // Prevent double taps
                          setStateDialog(() {
                            _isVerifying = true;
                          });

                          // call verification endpoint
                          final ok = await _verifyBookingOwner(
                              bookingId: booking['id'],
                              amount: booking['amount'] ?? 0);

                          setStateDialog(() {
                            _isVerifying = false;
                          });

                          if (ok) {
                            // Auto-close the dialog after verification (Option A)
                            try {
                              Navigator.pop(context);
                            } catch (_) {}
                            // Refresh slots + counts
                            await _fetchSlots();

                            // show confirmation
                            if (mounted) {
                              _showInfoDialog('Booking verified successfully.');
                            }
                          } else {
                            // on failure, keep dialog open and show error
                            if (mounted) {
                              _showErrorDialog('Failed to verify booking.');
                            }
                          }
                        },
                  child: _isVerifying
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryText,
                                )),
                            const SizedBox(width: 8),
                            Text('Verifying...',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: primaryText))
                          ],
                        )
                      : Text('VERIFY BOOKING',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, color: primaryText)),
                ),

              // 2) Calculate now (same as before)
              TextButton(
                onPressed: () {
                  exitTime = DateTime.now();
                  final secondsDifference =
                      exitTime.difference(entryTime).inSeconds;
                  setStateDialog(() {
                    calculatedAmount =
                        secondsDifference; // ₹1 per second (demo)
                  });
                },
                child: Text('Calculate Now',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: primaryText)),
              ),

              // 3) Pay & Complete (only show when calculatedAmount != null)
              if (calculatedAmount != null)
                TextButton(
                  onPressed: () {
                    // Start payment flow
                    // Save pending completion data
                    _pendingCompletionData = {
                      'booking_id': booking['id'],
                      'parking_id': booking['parking_id'],
                      'slot_number': booking['slot_number'],
                      'vehicle_type': booking['vehicle_type'],
                      'vehicle_number': booking['number_plate'],
                      'entry_time': booking['entry_time'],
                      'exit_time': exitTime.toIso8601String(),
                      'amount': calculatedAmount,
                    };

                    // start razorpay checkout if available, else call complete without payment_id
                    if (_razorpay != null) {
                      final options = <String, Object>{
                        'key': RAZORPAY_KEY,
                        'amount': (calculatedAmount! * 100), // paise
                        'name': 'Parking Exit Fee',
                        'description': 'Exit payment',
                        'prefill': {
                          'contact': widget.phone,
                          'email': 'owner@example.com'
                        },
                      };
                      try {
                        Navigator.pop(
                            context); // close details dialog to allow payment UI
                        _razorpay!.open(options);
                      } catch (e) {
                        _showErrorDialog('Payment error: $e');
                        _pendingCompletionData = null;
                      }
                    } else {
                      // No razorpay (web) — complete directly without payment_id
                      Navigator.pop(context);
                      _completeBookingOwner(_pendingCompletionData!, null);
                      _pendingCompletionData = null;
                    }
                  },
                  child: Text('Pay & Complete',
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
      debugPrint('Error fetching active booking details: $e');
      _showErrorDialog('Error fetching slot details: $e');
    }
  }

  /// Verifies a booking as the owner.
  /// Calls POST /api/bookings/verify with booking_id and a payment_id
  /// Uses `payment_id: 'owner_confirm'` so backend will accept it.
  Future<bool> _verifyBookingOwner({
    required dynamic bookingId,
    required dynamic amount,
  }) async {
    if (bookingId == null) return false;

    if (_isVerifying) return false;
    _isVerifying = true;
    _showProgressDialog('Verifying booking...');

    try {
      final body = {
        'booking_id': bookingId,
        'payment_id': 'owner_confirm',
        'amount': amount ?? 0,
      };

      final res = await http.post(
        Uri.parse('$apiScheme://$apiHost/api/bookings/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      Navigator.pop(context); // hide progress

      debugPrint('Verify status: ${res.statusCode}, body: ${res.body}');

      if (res.statusCode == 200) {
        return true;
      } else {
        /// EXTRACT REAL REASON (detail, message, or raw body)
        String serverReason = 'Unknown reason';
        try {
          final parsed = jsonDecode(res.body);
          if (parsed is Map) {
            if (parsed['detail'] != null) {
              serverReason = parsed['detail'].toString();
            } else if (parsed['message'] != null) {
              serverReason = parsed['message'].toString();
            } else {
              serverReason = res.body;
            }
          } else {
            serverReason = res.body;
          }
        } catch (e) {
          serverReason = 'Unexpected response: ${res.body}';
        }

        /// SHOW REAL ERROR MESSAGE
        _showErrorDialog(
          "Verification failed:\n\n$serverReason\n\n(HTTP ${res.statusCode})",
        );

        return false;
      }
    } catch (e) {
      try {
        Navigator.pop(context);
      } catch (_) {}

      debugPrint('Verify booking error: $e');

      _showErrorDialog("Network/error verifying booking:\n$e");

      return false;
    } finally {
      _isVerifying = false;
    }
  }

  // complete endpoint call
  Future<void> _completeBookingOwner(
      Map<String, dynamic> data, String? paymentId) async {
    // data must include booking_id, parking_id, vehicle_type, exit_time, amount
    try {
      // close any open dialog (caller should pop)
      _showProgressDialog('Completing booking...');

      final resp = await http.post(
          Uri.parse('$apiScheme://$apiHost/api/owner/bookings/complete'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'booking_id': data['booking_id'],
            'parking_id': data['parking_id'],
            'vehicle_type': data['vehicle_type'],
            'exit_time': data['exit_time'],
            'amount': data['amount'],
            'payment_id': paymentId
          }));

      Navigator.pop(context); // hide progress
      if (resp.statusCode == 200) {
        // show receipt
        final receipt = {
          'slot_number': data['slot_number'],
          'vehicle_number': data['vehicle_number'],
          'entry_time': data['entry_time'],
          'exit_time': data['exit_time'],
          'amount': data['amount'],
          'parking_name': widget.parkingAreaName
        };
        // refresh and navigate to success screen
        await _fetchSlots();
        if (mounted) {
          Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SuccessScreen(receipt: receipt)))
              .then((_) => _fetchSlots());
        }
      } else {
        final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
        final msg = (body is Map && body['message'] != null)
            ? body['message']
            : 'Failed to complete booking';
        _showErrorDialog(msg);
      }
    } catch (e) {
      try {
        Navigator.pop(context);
      } catch (_) {}
      debugPrint('Error completing booking: $e');
      _showErrorDialog('Error completing booking: $e');
    } finally {
      _pendingCompletionData = null;
    }
  }

  // Payment handlers
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingCompletionData == null) {
      _showErrorDialog('Payment succeeded but booking context lost.');
      return;
    }
    final paymentId = response.paymentId;
    await _completeBookingOwner(_pendingCompletionData!, paymentId);
    _pendingCompletionData = null;
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showErrorDialog('Payment failed: ${response.message}');
    _pendingCompletionData = null;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showErrorDialog('External wallet: ${response.walletName}');
    _pendingCompletionData = null;
  }

  // -------------------- Small UI helpers --------------------
  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: cardSurface, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(message, style: GoogleFonts.poppins(color: primaryText)),
            ],
          ),
        ),
      ),
    );
  }

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
                      fontWeight: FontWeight.bold, color: primaryText))),
        ],
      ),
    );
  }

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Info", style: GoogleFonts.poppins(color: primaryText)),
        content:
            Text(message, style: GoogleFonts.poppins(color: secondaryText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: GoogleFonts.poppins(color: primaryText)))
        ],
      ),
    );
  }

  // -------------------- Build UI (unchanged visually) --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        title: Text(widget.parkingAreaName,
            style: GoogleFonts.poppins(color: primaryText)),
        elevation: 0,
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: primaryText),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: primaryText),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ProfileScreen(phone: widget.phone))),
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
                    bottomRight: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.parkingAreaName,
                      style: GoogleFonts.poppins(
                          color: primaryText,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Manage your parking slots",
                      style: GoogleFonts.poppins(
                          color: secondaryText, fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _buildSlotCount(
                              Icons.directions_car,
                              "Cars",
                              _availableCarSlots,
                              _bookedCarSlots,
                              _totalCarSlots)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildSlotCount(
                              Icons.motorcycle,
                              "Bikes",
                              _availableBikeSlots,
                              _bookedBikeSlots,
                              _totalBikeSlots)),
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
                                offset: Offset(0, 4))
                          ]),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Select Vehicle Type",
                          labelStyle: GoogleFonts.poppins(color: hintText),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 0),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
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
                          if (value == null) return;
                          setState(() => _vehicleType = value);
                          // join new socket room & refresh slots
                          _joinSocketRoomIfReady();
                          _fetchSlots();
                        },
                        dropdownColor: cardSurface,
                        icon:
                            const Icon(Icons.arrow_drop_down, color: hintText),
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
                                offset: Offset(0, 4))
                          ]),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  _buildLegendItem(stateAvailable, "Available"),
                                  const SizedBox(width: 12),
                                  _buildLegendItem(stateHeld, "Held"),
                                  const SizedBox(width: 12),
                                  _buildLegendItem(statePending, "Pending"),
                                  const SizedBox(width: 12),
                                  _buildLegendItem(stateBooked, "Booked"),
                                ]),
                            const SizedBox(height: 20),
                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: markerColor))
                                : _slots.isEmpty
                                    ? Center(
                                        child: Text(
                                            "No slots available. Update parking area in Profile.",
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                                color: secondaryText)))
                                    : Wrap(
                                        spacing: 10.0,
                                        runSpacing: 10.0,
                                        children: _slots.map((slot) {
                                          final slotNumber =
                                              slot['slot_number'] as int;
                                          final String status =
                                              (slot['status'] ?? 'available')
                                                  .toString();
                                          final bool isBooked =
                                              status == 'booked';
                                          final bool isHeld = status == 'held';
                                          final bool isPending =
                                              status == 'pending';
                                          final heldBy = slot['held_by'];

                                          Color bgColor = stateAvailable;
                                          if (isBooked)
                                            bgColor = stateBooked;
                                          else if (isPending)
                                            bgColor = statePending;
                                          else if (isHeld) bgColor = stateHeld;

                                          return GestureDetector(
                                            onTap: () {
                                              if (isBooked || isPending) {
                                                _showBookedDetails(slot);
                                              } else if (isHeld) {
                                                // if held by you -> allow booking flow; else show message
                                                if (heldBy != null &&
                                                    heldBy.toString() ==
                                                        widget.phone) {
                                                  // allow manual booking (owner hold -> convert)
                                                  _bookSlot(slot);
                                                } else {
                                                  _showErrorDialog(
                                                      "This slot is temporarily held by a user.");
                                                }
                                              } else {
                                                _bookSlot(slot);
                                              }
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 200),
                                              width: 65,
                                              height: 65,
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: !isBooked
                                                    ? [
                                                        BoxShadow(
                                                            color: bgColor
                                                                .withOpacity(
                                                                    0.3),
                                                            blurRadius: 8,
                                                            offset:
                                                                const Offset(
                                                                    0, 2))
                                                      ]
                                                    : [],
                                              ),
                                              child: Center(
                                                child: Text("$slotNumber",
                                                    style: GoogleFonts.poppins(
                                                        color: primaryText,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16)),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                          ]),
                    ),
                  ]),
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
                color: markerColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.bold, color: primaryText)),
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
                color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 12, color: secondaryText)),
      ],
    );
  }

  Widget _buildSlotCount(
      IconData icon, String label, int available, int booked, int total) {
    final int displayTotal = total == 0 ? (available + booked) : total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: cardSurface, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, size: 20, color: primaryText),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("$available / $displayTotal",
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text("$label (Avail/Total)",
                style: GoogleFonts.poppins(fontSize: 12, color: secondaryText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}
