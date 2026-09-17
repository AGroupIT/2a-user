import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/main.dart' as entrypoint;
import 'package:twoalogisticcabineuser/src/core/ui/startup_screen.dart';

// Production creates its binding in main's guarded zone. The test binding is
// created by the harness earlier, so ignore only this harness zone mismatch.
class _BootstrapBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool debugCheckZone(String entryPoint) => true;
}

void main() {
  _BootstrapBinding();
  testWidgets(
    'actual main shows first frame, bounds hung storage and retries',
    (tester) async {
      final originalErrorHandler = FlutterError.onError;
      final originalPlatformErrorHandler =
          ui.PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = originalErrorHandler;
        ui.PlatformDispatcher.instance.onError = originalPlatformErrorHandler;
      });
      SharedPreferences.resetStatic();
      final originalPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = originalPlatform);
      final pending = Completer<Map<String, Object>>();
      const channel = MethodChannel('plugins.flutter.io/shared_preferences');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'getAll') return pending.future;
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      unawaited(entrypoint.main());
      await tester.pump();
      expect(find.byType(StartupScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      expect(
        find.text('Не удалось запустить приложение / 启动失败'),
        findsOneWidget,
      );
      await tester.tap(find.text('Повторить / 重试'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete({});
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      FlutterError.onError = originalErrorHandler;
      ui.PlatformDispatcher.instance.onError = originalPlatformErrorHandler;
      expect(find.byType(StartupScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
      debugDefaultTargetPlatformOverride = originalPlatform;
    },
  );
}
