import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production web build uploads exact artifacts then removes live maps',
    () {
      final dockerfile = File('Dockerfile').readAsStringSync();

      expect(
        dockerfile,
        contains('SENTRY_AUTH_TOKEN build secret is required'),
      );
      expect(
        dockerfile,
        contains(r'RESOLVED_SENTRY_DIST="$BUILD_NUMBER-$SOURCE_HASH"'),
      );
      expect(dockerfile, contains('dart run sentry_dart_plugin'));
      expect(
        dockerfile,
        contains("find build/web -type f -name '*.map' -delete"),
      );
      expect(
        dockerfile,
        contains(r"sed -i '/^[[:space:]]*\/\/# sourceMappingURL="),
      );

      final upload = dockerfile.indexOf('dart run sentry_dart_plugin');
      final deleteMaps = dockerfile.indexOf(
        "find build/web -type f -name '*.map' -delete",
      );
      expect(upload, greaterThanOrEqualTo(0));
      expect(deleteMaps, greaterThan(upload));
    },
  );
}
