/// Вложение к сообщению чата
class ChatAttachment {
  final int id;
  final String fileName;
  final String fileType;
  final int? fileSize;
  final String url;
  final String? thumbnailUrl;

  const ChatAttachment({
    required this.id,
    required this.fileName,
    required this.fileType,
    this.fileSize,
    required this.url,
    this.thumbnailUrl,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id'] as int,
      fileName: (json['fileName'] ?? json['file_name']) as String? ?? '',
      fileType: (json['fileType'] ?? json['file_type']) as String? ?? '',
      fileSize: (json['fileSize'] ?? json['file_size']) as int?,
      url: json['url'] as String? ?? '',
      thumbnailUrl: (json['thumbnailUrl'] ?? json['thumbnail_url']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  ChatAttachment copyWith({
    int? id,
    String? fileName,
    String? fileType,
    int? fileSize,
    String? url,
    String? thumbnailUrl,
  }) {
    return ChatAttachment(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  bool get isImage => fileType.startsWith('image/');
  bool get isPdf => fileType == 'application/pdf';
  bool get isDocument => !isImage;

  /// Иконка для документа по расширению/типу
  static String documentExtension(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ext;
  }
}
