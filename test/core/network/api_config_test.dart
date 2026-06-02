import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_config.dart';

void main() {
  group('ApiConfig API hosts', () {
    test('uses legacy public backend as default mobile fallback', () {
      expect(
        ApiConfig.fallbackBaseUrl,
        'https://2alogistic.2a-marketing.ru/api',
      );
    });
  });

  group('ApiConfig media thumbnails', () {
    test('builds thumbnail URL for relative uploads path', () {
      expect(
        ApiConfig.getMediaThumbnailUrl('uploads/photos/item.jpg', size: 320),
        'https://prod-api.cp.2a-logistic.com/api/uploads/thumb/360/photos/item.jpg',
      );
    });

    test('rewrites legacy uploads URL to current thumbnail endpoint', () {
      expect(
        ApiConfig.getMediaThumbnailUrl(
          'https://2alogistic.2a-marketing.ru/uploads/photos/item.png',
          size: 720,
        ),
        'https://prod-api.cp.2a-logistic.com/api/uploads/thumb/720/photos/item.png',
      );
    });

    test('keeps unsupported media on original media URL', () {
      expect(
        ApiConfig.getMediaThumbnailUrl('uploads/videos/item.mp4'),
        'https://prod-api.cp.2a-logistic.com/api/uploads/videos/item.mp4',
      );
    });

    test('keeps non-upload absolute image URL unchanged', () {
      const url = 'https://example.com/image.jpg';
      expect(ApiConfig.getMediaThumbnailUrl(url), url);
    });
  });
}
