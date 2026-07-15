import 'package:flutter_test/flutter_test.dart';
import 'package:smartchama/services/mpesa_service.dart';

void main() {
  group('MpesaService phone formatting', () {
    test('formats local Safaricom numbers to 254 prefix', () {
      expect(MpesaService.formatPhone('0712345678'), '254712345678');
      expect(MpesaService.formatPhone('712345678'), '254712345678');
      expect(MpesaService.formatPhone('+254712345678'), '254712345678');
      expect(MpesaService.formatPhone('254712345678'), '254712345678');
    });

    test('validates Kenya Safaricom numbers', () {
      expect(MpesaService.isValidKenyaPhone('0712345678'), isTrue);
      expect(MpesaService.isValidKenyaPhone('0112345678'), isFalse);
      expect(MpesaService.isValidKenyaPhone('7123456'), isFalse);
    });
  });

  group('MpesaService pay validation', () {
    test('rejects missing chama context', () async {
      final result = await MpesaService.pay(
        phone: '0712345678',
        amount: 100,
        userId: 'user-1',
        organizationId: '',
        chamaId: '',
        idToken: 'token',
        type: 'contribution',
      );

      expect(result['success'], isFalse);
      expect(result['error'], contains('chama'));
    });

    test('rejects invalid phone numbers', () async {
      final result = await MpesaService.pay(
        phone: '12345',
        amount: 100,
        userId: 'user-1',
        organizationId: 'org-1',
        chamaId: 'chama-1',
        idToken: 'token',
        type: 'contribution',
      );

      expect(result['success'], isFalse);
      expect(result['error'], contains('valid Safaricom'));
    });

    test('rejects amounts below KES 1', () async {
      final result = await MpesaService.pay(
        phone: '0712345678',
        amount: 0,
        userId: 'user-1',
        organizationId: 'org-1',
        chamaId: 'chama-1',
        idToken: 'token',
        type: 'contribution',
      );

      expect(result['success'], isFalse);
      expect(result['error'], contains('at least KES 1'));
    });
  });
}
