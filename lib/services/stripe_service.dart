import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Stripe secret keys must only be used on a trusted backend.
/// From the Flutter app, call your server to create payment intents.
class StripeService {
  static const String _baseUrl = 'https://api.stripe.com/v1';
  static String? _apiKey;

  @Deprecated('Use a backend proxy; never pass Stripe secret keys in the app')
  static void initialize({required String secretKey}) {
    if (kDebugMode) {
      debugPrint(
        'Warning: Stripe secret keys must not be embedded in client apps.',
      );
    }
    _apiKey = secretKey;
  }

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    headers: {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  ));

  static Future<String?> createPaymentIntent({
    required double amount,
    required String currency,
    String? customerId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final data = {
        'amount': (amount * 100).toInt(),
        'currency': currency.toLowerCase(),
        if (customerId != null) 'customer': customerId,
        if (metadata != null) 'metadata': metadata,
      };

      final response = await _dio.post('/payment_intents', data: data);

      if (response.statusCode == 200) {
        return response.data['client_secret'];
      }
      return null;
    } catch (e) {
      debugPrint('Stripe error: $e');
      return null;
    }
  }

  static Future<String?> createCustomer({
    required String email,
    required String name,
  }) async {
    try {
      final data = {
        'email': email,
        'name': name,
      };

      final response = await _dio.post('/customers', data: data);

      if (response.statusCode == 200) {
        return response.data['id'];
      }
      return null;
    } catch (e) {
      debugPrint('Stripe error: $e');
      return null;
    }
  }

  static Future<bool> createSubscription({
    required String customerId,
    required String priceId,
  }) async {
    try {
      final data = {
        'customer': customerId,
        'items[0][price]': priceId,
      };

      final response = await _dio.post('/subscriptions', data: data);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Stripe error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getPaymentMethods(
      String customerId) async {
    try {
      final response = await _dio.get('/payment_methods', queryParameters: {
        'customer': customerId,
        'type': 'card',
      });

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Stripe error: $e');
      return [];
    }
  }

  static Future<bool> detachPaymentMethod(String paymentMethodId) async {
    try {
      final response =
          await _dio.post('/payment_methods/$paymentMethodId/detach');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Stripe error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getPaymentIntent(
      String paymentIntentId) async {
    try {
      final response = await _dio.get('/payment_intents/$paymentIntentId');

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('Stripe error: $e');
      return null;
    }
  }
}

// Debug print helper
void debugPrint(String message) {
  assert(() {
    // ignore: avoid_print
    print(message);
    return true;
  }());
}
