@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:twoalogisticcabineuser/src/core/media/private_video_source_web.dart';

void main() {
  test(
    'browser audio creates a disposable local blob without credentials',
    () async {
      final source = await createPrivateMediaSource(
        Uint8List.fromList([1, 2, 3]),
        'audio/mpeg',
      );
      expect(Uri.parse(source.url).scheme, 'blob');
      expect(source.url, isNot(contains('Bearer')));
      await source.dispose();
    },
  );
  test(
    'browser video player receives only a local blob and no headers',
    () async {
      final controller = await createPrivateVideoSource(
        Uint8List.fromList([1, 2, 3]),
        'video/mp4',
      );
      expect(Uri.parse(controller.dataSource).scheme, 'blob');
      expect(controller.dataSourceType, DataSourceType.network);
      expect(controller.httpHeaders, isEmpty);
      await controller.dispose();
    },
  );
}
