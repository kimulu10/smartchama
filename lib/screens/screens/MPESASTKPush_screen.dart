import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MpesaStkPushScreen extends StatefulWidget {
  final double amount;
  final String phoneNumber; // Format: 2547XXXXXXXX
  final String reference; // e.g., "Loan repayment" or "Contribution"

  const MpesaStkPushScreen({
    super.key,
    required this.amount,
    required this.phoneNumber,
    required this.reference,
  });

  @override
  State<MpesaStkPushScreen> createState() => _MpesaStkPushScreenState();
}

class _MpesaStkPushScreenState extends State<MpesaStkPushScreen> {
  bool isLoading = false;
  String status = "Pending";

  // TODO: Replace these with your Daraja sandbox/production credentials
  final String consumerKey = "YOUR_CONSUMER_KEY";
  final String consumerSecret = "YOUR_CONSUMER_SECRET";
  final String shortcode = "YOUR_SHORTCODE";
  final String lipaNaMpesaPasskey = "YOUR_PASSKEY";
  final String callbackUrl = "https://your-server.com/mpesa_callback"; // Optional

  Future<void> startStkPush() async {
    setState(() => isLoading = true);

    try {
      // Step 1: Get OAuth Token
      final credentials = base64.encode(utf8.encode('$consumerKey:$consumerSecret'));
      final tokenResponse = await http.get(
        Uri.parse("https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"),
        headers: {"Authorization": "Basic $credentials"},
      );
      final tokenData = json.decode(tokenResponse.body);
      final accessToken = tokenData['access_token'];

      // Step 2: Prepare STK Push
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[-:]|\.\d{3}'), '').substring(0, 14);
      final password = base64.encode(utf8.encode("$shortcode$lipaNaMpesaPasskey$timestamp"));

      final stkPushBody = json.encode({
        "BusinessShortCode": shortcode,
        "Password": password,
        "Timestamp": timestamp,
        "TransactionType": "CustomerPayBillOnline",
        "Amount": widget.amount.toInt(),
        "PartyA": widget.phoneNumber,
        "PartyB": shortcode,
        "PhoneNumber": widget.phoneNumber,
        "CallBackURL": callbackUrl,
        "AccountReference": widget.reference,
        "TransactionDesc": widget.reference,
      });

      final stkResponse = await http.post(
        Uri.parse("https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest"),
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: stkPushBody,
      );

      final stkData = json.decode(stkResponse.body);
      if (stkData['ResponseCode'] == "0") {
        setState(() => status = "STK Push sent! Check your phone to complete payment.");
      } else {
        setState(() => status = "Error: ${stkData['ResponseDescription']}");
      }

    } catch (e) {
      setState(() => status = "Error: $e");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("M-Pesa Payment")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Amount: KES ${widget.amount.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("Phone: ${widget.phoneNumber}"),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: startStkPush,
                    child: const Text("Pay via M-Pesa"),
                  ),
            const SizedBox(height: 20),
            Text(
              status,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
} 