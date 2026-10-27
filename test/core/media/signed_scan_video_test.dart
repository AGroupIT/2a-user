import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:twoalogisticcabineuser/src/core/media/authenticated_video.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_config.dart';

void main() {
  testWidgets(
    'signed scan recordings stream with no account credentials or download',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      // No ProviderScope is installed: any API lookup/download would fail.
      final controller = await createAuthenticatedVideoController(
        context,
        '${ApiConfig.mediaBaseUrl}/api/assembly-scan-media/playback?token=signed%2Btoken',
      );
      final uri = Uri.parse(controller.dataSource);
      expect(controller.dataSourceType, DataSourceType.network);
      expect(controller.httpHeaders, isEmpty);
      expect(uri.origin, Uri.parse(ApiConfig.baseUrl).origin);
      expect(uri.path, '/api/assembly-scan-media/playback');
      expect(uri.queryParameters['token'], 'signed+token');
      expect(uri.queryParameters['proxy'], '1');
      await controller.dispose();
    },
  );
}
