import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:lottie/lottie.dart';

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

class SuccessScreen extends StatelessWidget {
  final Map<String, dynamic> receipt;

  const SuccessScreen({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final isPayment = receipt['amount'] != null;

    return Scaffold(
      backgroundColor: appBackground, // New Color
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                  24, 60, 24, 24), // Add padding for status bar
              decoration: const BoxDecoration(
                color: appBarColor, // New Color
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isPayment ? "Payment Successful!" : "Booking Confirmed!",
                    style: GoogleFonts.poppins(
                      // New Style
                      color: primaryText,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPayment
                        ? "Your payment has been processed"
                        : "Your parking slot is reserved",
                    style: GoogleFonts.poppins(
                      // New Style
                      color: secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Lottie.asset(
                    'assets/lottie/success.json', // Make sure this asset is in your pubspec.yaml
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity, // Ensure card takes full width
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
                        _buildSectionTitle(
                            isPayment ? "Payment Receipt" : "Booking Details"),
                        const SizedBox(height: 16),
                        _buildDetailRow(Icons.local_parking, "Slot",
                            "${receipt['slot_number']}"),
                        const SizedBox(height: 12),
                        _buildDetailRow(Icons.directions_car, "Vehicle Number",
                            "${receipt['vehicle_number']}"),
                        const SizedBox(height: 12),
                        _buildDetailRow(Icons.access_time, "Entry Time",
                            "${receipt['entry_time']}"),
                        if (receipt['exit_time'] != null) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.access_time, "Exit Time",
                              "${receipt['exit_time']}"),
                        ],
                        if (receipt['date'] != null) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.calendar_today, "Date",
                              "${receipt['date']}"),
                        ],
                        if (receipt['parking_name'] != null) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.local_parking, "Parking Name",
                              "${receipt['parking_name']}"),
                        ],
                        if (receipt['amount'] != null) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.money, "Amount Paid",
                              "₹${receipt['amount']}"),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
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
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Back to Home",
                        style: GoogleFonts.poppins(
                          // New Style
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: infoItemBg, // New Color
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: markerColor), // New Color
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                    // New Style
                    fontSize: 14,
                    color: secondaryText),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                    // New Style
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
