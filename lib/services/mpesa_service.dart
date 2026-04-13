import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// M-Pesa client used by the Flutter app.
///
/// Note: This app uses an Express backend (`mpesa-backend/server.js`) to
/// interact with Safaricom Daraja. The Flutter code just triggers STK Push
/// and polls `/transaction-status/:checkoutRequestID`.
class MpesaService {
  /// Base URL for the backend.
  /// 
  /// IMPORTANT: Update this URL to your current ngrok URL
  /// Run: ngrok http 3000
  /// Then update the URL below
  static const String _defaultBaseUrl =
      'https://smartchama-mpesa-.onrender.com';
  static const String baseUrl =
      String.fromEnvironment('MPESA_BASE_URL', defaultValue: _defaultBaseUrl);

  /// Format local Kenya numbers into `2547XXXXXXXX` (no `+`).
  static String formatPhone(String input) {
    var phone = input.trim().replaceAll(' ', '');
    if (phone.startsWith('+')) phone = phone.substring(1);

    // Already in international format.
    if (phone.startsWith('254')) return phone;

    // Kenya local: 07XXXXXXXX -> 2547XXXXXXXX
    if (phone.startsWith('0')) {
      return '254${phone.substring(1)}';
    }

    // Kenya short: 7XXXXXXXX -> 2547XXXXXXXX
    if (phone.startsWith('7')) {
      return '254$phone';
    }

    return phone;
  }

/// Trigger STK Push.
///
/// [type] must match the backend contract:
/// - `contribution`
/// - `loan_repayment`
static Future<Map<String, dynamic>> pay({
    required String phone,
    required double amount,
    required String userId,
    required String organizationId,
    required String chamaId,
    String? loanId,
    required String type,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/stkpush');
      final body = jsonEncode({
        'phone': formatPhone(phone),
        'amount': amount,
        'userId': userId,
        'organizationId': organizationId,
        'chamaId': chamaId,
        'loanId': loanId,
        'type': type,
      });

      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && decoded['success'] == true) {
        return decoded;
      }

      return {
        'success': false,
        'error': decoded['error'] ?? decoded,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Poll the backend until the payment callback updates the transaction.
  static Future<String> waitForTransactionCompletion(
    String checkoutRequestID, {
    Duration interval = const Duration(seconds: 5),
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      try {
        final uri =
            Uri.parse('$baseUrl/transaction-status/$checkoutRequestID');
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final status = decoded['status'];
          if (status == 'success' || status == 'failed') {
            return status as String;
          }
        }
      } catch (_) {
        // Ignore polling failures; keep polling until timeout.
      }

      await Future.delayed(interval);
    }

    return 'pending';
  }

  static Future<Map<String, dynamic>> payContribution({
    required String phone,
    required double amount,
    required String userId,
    required String organizationId,
    required String chamaId,
  }) async {
    return pay(
      phone: phone,
      amount: amount,
      userId: userId,
      organizationId: organizationId,
      chamaId: chamaId,
      type: 'contribution',
    );
  }

  static Future<Map<String, dynamic>> payLoan({
    required String phone,
    required double amount,
    required String userId,
    required String organizationId,
    required String chamaId,
    required String loanId,
  }) async {
    return pay(
      phone: phone,
      amount: amount,
      userId: userId,
      organizationId: organizationId,
      chamaId: chamaId,
      loanId: loanId,
      type: 'loan_repayment',
    );
  }
}