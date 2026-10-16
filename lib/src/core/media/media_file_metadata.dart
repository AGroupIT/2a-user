/// Keep the original media format when saving or sharing downloaded bytes.
String mediaFileName(String url, {required bool isVideo}) {
  final uri = Uri.tryParse(url);
  final name = uri?.pathSegments.lastOrNull;
  if (name != null &&
      name.isNotEmpty &&
      !name.contains(RegExp(r'[/\\\x00-\x1f]')) &&
      _mediaMimeTypes.containsKey(name.split('.').last.toLowerCase())) {
    return name;
  }
  return isVideo ? 'video.mp4' : 'photo.jpg';
}

String mediaMimeType(String url, {required bool isVideo}) =>
    _mediaMimeTypes[mediaFileName(
      url,
      isVideo: isVideo,
    ).split('.').last.toLowerCase()]!;

const _mediaMimeTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'm4v': 'video/x-m4v',
  'webm': 'video/webm',
};
