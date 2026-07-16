import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/utils/gallery_image_save_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('gal');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('сохраняет PNG в галерею и передаёт имя без расширения', () async {
    MethodCall? saveCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'hasAccess':
          return true;
        case 'putImageBytes':
          saveCall = call;
          return null;
      }
      return null;
    });

    final result = await saveImageToGallery(
      bytes: Uint8List.fromList([137, 80, 78, 71]),
      fileName: '2a_invoice_test_qr.png',
    );

    expect(result.success, isTrue);
    expect(result.destination, SavedImageDestination.gallery);
    expect(saveCall?.arguments['name'], '2a_invoice_test_qr');
  });

  test('возвращает ошибку, если доступ к галерее не выдан', () async {
    var saveWasCalled = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'hasAccess':
        case 'requestAccess':
          return false;
        case 'putImageBytes':
          saveWasCalled = true;
          return null;
      }
      return null;
    });

    final result = await saveImageToGallery(
      bytes: Uint8List.fromList([137, 80, 78, 71]),
      fileName: 'qr.png',
    );

    expect(result.success, isFalse);
    expect(saveWasCalled, isFalse);
  });
}
