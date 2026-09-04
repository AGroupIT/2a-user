import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';

void main() {
  test('push registration retry uses bounded exponential delays', () {
    expect(pushRegistrationRetryDelay(0), const Duration(seconds: 15));
    expect(pushRegistrationRetryDelay(1), const Duration(seconds: 30));
    expect(pushRegistrationRetryDelay(2), const Duration(seconds: 60));
    expect(pushRegistrationRetryDelay(3), const Duration(seconds: 120));
    expect(pushRegistrationRetryDelay(4), const Duration(seconds: 300));
    expect(pushRegistrationRetryDelay(100), const Duration(seconds: 300));
  });
}
