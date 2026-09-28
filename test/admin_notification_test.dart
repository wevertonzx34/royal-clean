import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/admin_push_royal_clean.dart';

void main() {
  test(
    'Android notification ids are typed, stable and bounded for FCM data',
    () {
      final Map<String, dynamic> payload = {
        'eventId': 'products_12345678901234',
      };
      final id = adminNotificationIdRoyalClean(payload['eventId'] as String);
      expect(id, inInclusiveRange(0, 0x7fffffff));
      expect(id, adminNotificationIdRoyalClean('products_12345678901234'));
      expect(
        id,
        isNot(adminNotificationIdRoyalClean('invoices_12345678901234')),
      );
    },
  );
}
