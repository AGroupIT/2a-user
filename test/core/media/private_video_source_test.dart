import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/media/private_video_source_io.dart';
import 'package:video_player/video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'private audio uses a disposable local source with the right extension',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'private-audio-test-',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final source = await createPrivateMediaSource(
        Uint8List.fromList([1, 2, 3]),
        'audio/mpeg',
      );
      expect(Uri.parse(source.url).scheme, 'file');
      final file = File.fromUri(Uri.parse(source.url));
      expect(file.path, endsWith('.mp3'));
      expect(await file.readAsBytes(), [1, 2, 3]);
      await Future.wait([source.dispose(), source.dispose()]);
      expect(await file.exists(), false);
      expect(await file.parent.exists(), false);
    },
  );
  test(
    'native private video uses a disposable local file without bearer headers',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'private-video-test-',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final controller = await createPrivateVideoSource(
        Uint8List.fromList([1, 2, 3]),
        'video/mp4',
      );
      expect(controller.dataSourceType, DataSourceType.file);
      expect(controller.httpHeaders, isEmpty);
      final file = File.fromUri(Uri.parse(controller.dataSource));
      expect(await file.readAsBytes(), [1, 2, 3]);
      final parent = file.parent;
      await controller.dispose();
      expect(await file.exists(), false);
      expect(await parent.exists(), false);
    },
  );
}
