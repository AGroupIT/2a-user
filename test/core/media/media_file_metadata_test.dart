import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/media/media_file_metadata.dart';

void main() {
  test('preserves image and video formats without query or fragment', () {
    expect(mediaFileName('/uploads/a.PNG?size=1#x', isVideo: false), 'a.PNG');
    expect(mediaMimeType('/uploads/a.PNG?size=1', isVideo: false), 'image/png');
    expect(mediaFileName('/uploads/a.webm', isVideo: true), 'a.webm');
    expect(mediaMimeType('/uploads/a.webm', isVideo: true), 'video/webm');
    expect(mediaMimeType('/uploads/a.mov', isVideo: true), 'video/quicktime');
  });
  test('extensionless playback and unsafe filenames receive safe defaults', () {
    expect(
      mediaFileName('/api/playback?token=private', isVideo: true),
      'video.mp4',
    );
    expect(mediaFileName('/uploads/a%2fb.png', isVideo: false), 'photo.jpg');
    expect(mediaFileName('/uploads/a%00.png', isVideo: false), 'photo.jpg');
    expect(
      mediaMimeType('/uploads/no-extension', isVideo: false),
      'image/jpeg',
    );
  });
}
