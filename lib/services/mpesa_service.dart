import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// M-Pesa client — talks to the Express backend (`mpesa-backend/server.js`).
class MpesaService {
  static const String _defaultBaseUrl =
      'https://stk-push-api-4flq.onrender.com';
  static const String baseUrl =
      String.fromEnvironment('MPESA_BASE_URL', defaultValue: _defaultBaseUrl);

  static String formatPhone(String input) {
    var phone = input.trim().replaceAll(' ', '');
    if (phone.startsWith('+')) phone = phone.substring(1);
    if (phone.startsWith('254')) return phone;
    if (phone.startsWith('0')) return '254${phone.substring(1)}';
    if (phone.startsWith('7') && phone.length == 9) return '254$phone';
    return phone;
  }

  static bool isValidKenyaPhone(String input) {
    final formatted = formatPhone(input);
    return RegExp(r'^2547\d{8}$').hasMatch(formatted);
  }

  static Future<bool> isBackendReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['ok'] == true;
      }
    } catch (_) {}
    return false;
  }

  static String _errorMessage(dynamic error) {
    if (error is Map) {
      return error['errorMessage']?.toString() ??
          error['error']?.toString() ??
          error.toString();
    }
    return error.toString();
  }

  static Map<String, String> _headers({required String idToken}) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      };

  static Future<Map<String, dynamic>> pay({
    required String phone,
    required double amount,
    required String userId,
    required String organizationId,
    required String chamaId,
    required String idToken,
    String? loanId,
    required String type,
  }) async {
    if (organizationId.isEmpty || chamaId.isEmpty) {
      return {
        'success': false,
        'error': 'Join or create a chama before paying with M-Pesa.',
      };
    }
    if (!isValidKenyaPhone(phone)) {
      return {
        'success': false,
        'error': 'Enter a valid Safaricom number (e.g. 0712345678).',
      };
    }
    if (amount < 1) {
      return {'success': false, 'error': 'Amount must be at least KES 1.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/stkpush');
      final body = jsonEncode({
        'phone': formatPhone(phone),
        'amount': amount.round(),
        'userId': userId,
        'organizationId': organizationId,
        'chamaId': chamaId,
        'loanId': loanId,
        'type': type,
      });

      final response = await http
          .post(
            uri,
            headers: _headers(idToken: idToken),
            body: body,
          )
          .timeout(const Duration(seconds: 45));

      Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {
          'success': false,
          'error': 'Invalid response from payment server (${response.statusCode}).',
        };
      }

      if (response.statusCode == 200 && decoded['success'] == true) {
        return decoded;
      }

      return {
        'success': false,
        'error': _errorMessage(decoded['error'] ?? decoded),
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Payment server timed out. Check your internet and try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Cannot reach M-Pesa server. Ensure the backend is running at $baseUrl',
      };
    }
  }

  static Future<String> waitForTransactionCompletion(
    String checkoutRequestID, {
    required String idToken,
    Duration interval = const Duration(seconds: 4),
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      try {
        final uri =
            Uri.parse('$baseUrl/transaction-status/$checkoutRequestID');
        final response = await http
            .get(uri, headers: _headers(idToken: idToken))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final status = decoded['status'];
          if (status == 'success' || status == 'failed') {
            return status as String;
          }
        }
      } catch (_) {}

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
    required String idToken,
  }) =>
      pay(
        phone: phone,
        amount: amount,
        userId: userId,
        organizationId: organizationId,
        chamaId: chamaId,
        idToken: idToken,
        type: 'contribution',
      );

  static Future<Map<String, dynamic>> payLoan({
    required String phone,
    required double amount,
    required String userId,
    required String organizationId,
    required String chamaId,
    required String loanId,
    required String idToken,
  }) =>
      pay(
        phone: phone,
        amount: amount,
        userId: userId,
        organizationId: organizationId,
        chamaId: chamaId,
        loanId: loanId,
        idToken: idToken,
        type: 'loan_repayment',
      );
}
