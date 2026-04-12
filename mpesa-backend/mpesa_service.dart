import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// =========================
/// MpesaService - Flutter M-Pesa Integration
/// =========================
class MpesaService {
  // 🔴 REPLACE WITH YOUR NGROK URL
  static const String baseUrl =
      "https://unsinuously-climatologic-akiko.ngrok-free.dev";

  /// =========================
  /// 📞 Format phone number (07 → 2547)
  /// =========================
  static String formatPhone(String phone) {
    phone = phone.trim();
    if (phone.startsWith("0")) return "254${phone.substring(1)}";
    if (phone.startsWith("7")) return "254$phone";
    return phone;
  }

  /// =========================
  /// 💳 Trigger STK Push (contribution or loan)
  /// =========================
  static Future<Map<String, dynamic>> pay({
    required String phone,
    required double amount,
    required String userId,
    required String chamaId,
    String? loanId,
    required String type, // "contribution" or "loan_repayment"
  }) async {
    try {
      final url = Uri.parse("$baseUrl/stkpush");

      final body = jsonEncode({
        "phone": formatPhone(phone),
        "amount": amount,
        "userId": userId,
        "chamaId": chamaId,
        "loanId": loanId,
        "type": type,
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ MPESA STK Push Response: $data");
        return {
          "success": true,
          "checkoutRequestID": data["checkoutRequestID"] ?? "",
          "transactionDocId": data["transactionDocId"] ?? "",
          "responseDescription": data["responseDescription"] ?? "",
        };
      } else {
        print("❌ MPESA STK Push Failed: ${response.body}");
        return {"success": false, "error": response.body};
      }
    } catch (e) {
      print("❌ MPESA Exception: $e");
      return {"success": false, "error": e.toString()};
    }
  }

  /// =========================
  /// 🔹 Wait for Transaction Completion
  /// =========================
  static Future<String> waitForTransactionCompletion(
    String checkoutRequestID, {
    Duration interval = const Duration(seconds: 5),
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      try {
        final url = Uri.parse("$baseUrl/transaction-status/$checkoutRequestID");
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data["status"];
          print("⏱ Transaction status: $status");

          if (status == "success" || status == "failed") {
            return status;
          }
        } else {
          print("❌ Error fetching transaction status: ${response.body}");
        }
      } catch (e) {
        print("❌ Exception fetching transaction status: $e");
      }

      await Future.delayed(interval);
    }

    return "pending"; // timeout reached
  }

  /// =========================
  /// 💰 Convenience: Pay Contribution
  /// =========================
  static Future<Map<String, dynamic>> payContribution({
    required String phone,
    required double amount,
    required String userId,
    required String chamaId,
  }) async {
    return await pay(
      phone: phone,
      amount: amount,
      userId: userId,
      chamaId: chamaId,
      type: "contribution",
    );
  }

  /// =========================
  /// 💳 Convenience: Pay Loan
  /// =========================
  static Future<Map<String, dynamic>> payLoan({
    required String phone,
    required double amount,
    required String userId,
    required String chamaId,
    required String loanId,
  }) async {
    return await pay(
      phone: phone,
      amount: amount,
      userId: userId,
      chamaId: chamaId,
      loanId: loanId,
      type: "loan_repayment",
    );
  }
}

/// =========================
/// Flutter Page: MpesaPaymentPage
/// =========================
class MpesaPaymentPage extends StatefulWidget {
  const MpesaPaymentPage({super.key});

  @override
  State<MpesaPaymentPage> createState() => _MpesaPaymentPageState();
}

class _MpesaPaymentPageState extends State<MpesaPaymentPage> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _loanIdController = TextEditingController();

  String _paymentType = 'contribution'; // default
  bool _isProcessing = false;
  String _statusMessage = "";

  Future<void> _pay() async {
    final phone = _phoneController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final loanId = _loanIdController.text.trim();

    if (phone.isEmpty || amount == null) {
      setState(() {
        _statusMessage = "Please enter valid phone and amount.";
      });
      return;
    }

    if (_paymentType == "loan_repayment" && loanId.isEmpty) {
      setState(() {
        _statusMessage = "Please enter Loan ID for loan repayment.";
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Initiating payment...";
    });

    // Trigger STK Push
    final result = await MpesaService.pay(
      phone: phone,
      amount: amount,
      userId: "USER_ID_HERE", // Replace with actual user ID
      chamaId: "CHAMA_ID_HERE", // Replace with actual chama ID
      loanId: _paymentType == "loan_repayment" ? loanId : null,
      type: _paymentType,
    );

    if (!result["success"]) {
      setState(() {
        _statusMessage = "Payment initiation failed: ${result["error"]}";
        _isProcessing = false;
      });
      return;
    }

    final checkoutRequestID = result["checkoutRequestID"];
    setState(() {
      _statusMessage = "STK Push sent. Waiting for completion...";
    });

    // Poll for completion
    final status = await MpesaService.waitForTransactionCompletion(checkoutRequestID);
    setState(() {
      _statusMessage = "Transaction status: $status";
      _isProcessing = false;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _loanIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("M-Pesa Payment"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                hintText: "07XXXXXXXX",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount",
                hintText: "Enter amount in KES",
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _paymentType,
              items: const [
                DropdownMenuItem(value: "contribution", child: Text("Contribution")),
                DropdownMenuItem(value: "loan_repayment", child: Text("Loan Repayment")),
              ],
              onChanged: (value) {
                setState(() {
                  _paymentType = value!;
                });
              },
              decoration: const InputDecoration(
                labelText: "Payment Type",
              ),
            ),
            if (_paymentType == "loan_repayment")
              TextField(
                controller: _loanIdController,
                decoration: const InputDecoration(
                  labelText: "Loan ID",
                  hintText: "Enter your loan ID",
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isProcessing ? null : _pay,
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Pay Now"),
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}