import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SuccessScreen extends StatelessWidget {
  final Map<String, dynamic> receipt;

  const SuccessScreen({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    // Determine if this is a payment or booking success based on presence of 'amount'
    final isPayment = receipt['amount'] != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isPayment ? "Payment Successful!" : "Booking Confirmed!",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPayment
                        ? "Your payment has been processed"
                        : "Your parking slot is reserved",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
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
                    'assets/lottie/success.json',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF3F51B5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Back to Home",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3F51B5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF3F51B5)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
