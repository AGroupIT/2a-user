import 'dart:convert';

import '../network/api_config.dart';

/// Утилита для конвертации Quill Delta JSON в plain text
///
/// Delta формат: [{"insert":"Текст\n"},{"insert":"Ещё текст","attributes":{"bold":true}}]
class DeltaConverter {
  /// Конвертирует Delta JSON строку в plain text
  /// Если строка не является валидным Delta JSON, возвращает её как есть
  static String toPlainText(String content) {
    if (content.isEmpty) return '';

    try {
      final json = jsonDecode(content);
      final ops = _extractOps(json);
      if (ops != null) return _extractTextFromDelta(ops);
    } catch (_) {
      // Не JSON - возвращаем как есть
    }
    return content;
  }

  /// Конвертирует Delta JSON строку в Markdown
  /// Поддерживает bold, italic, заголовки, списки
  static String toMarkdown(String content) {
    if (content.isEmpty) return '';

    try {
      final json = jsonDecode(content);
      final ops = _extractOps(json);
      if (ops != null) return _convertDeltaToMarkdown(ops);
    } catch (_) {
      // Не JSON - возвращаем как есть
    }
    return content;
  }

  static List<dynamic>? _extractOps(dynamic json) {
    if (json is List) return json;
    if (json is Map && json['ops'] is List) return json['ops'] as List<dynamic>;
    return null;
  }

  /// Извлекает plain text из Delta операций
  static String _extractTextFromDelta(List<dynamic> operations) {
    final buffer = StringBuffer();

    for (final op in operations) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is String) {
          buffer.write(insert);
        } else if (insert is Map) {
          // Для embed объектов (изображения и т.д.) добавляем placeholder
          if (insert.containsKey('image')) {
            buffer.write('[Изображение]');
          }
        }
      }
    }

    return buffer.toString().trim();
  }

  /// Конвертирует Delta в Markdown с поддержкой форматирования.
  ///
  /// В Quill/Fleather формат строки (`header`, `list`, `blockquote`) часто
  /// хранится на операции перевода строки `\n`, поэтому конвертация должна
  /// применять эти атрибуты к уже накопленной строке, а не только к текущему
  /// фрагменту текста.
  static String _convertDeltaToMarkdown(List<dynamic> operations) {
    final buffer = StringBuffer();
    final line = StringBuffer();

    void flushLine(Map<String, dynamic>? lineAttributes) {
      final text = line.toString();
      if (text.isNotEmpty) {
        final prefix = _lineMarkdownPrefix(lineAttributes);
        if (prefix.isNotEmpty) buffer.write(prefix);
        buffer.write(text);
      }
      buffer.write('\n');
      line.clear();
    }

    for (final op in operations) {
      if (op is! Map || !op.containsKey('insert')) continue;

      final insert = op['insert'];
      final attributes = op['attributes'] as Map<String, dynamic>?;

      if (insert is String) {
        final lines = insert.split('\n');

        for (var i = 0; i < lines.length; i++) {
          final segment = lines[i];
          if (segment.isNotEmpty) {
            line.write(_inlineMarkdown(segment, attributes));
          }

          if (i < lines.length - 1) {
            flushLine(attributes);
          }
        }
      } else if (insert is Map) {
        final imageUrl = _extractImageUrl(insert);
        if (imageUrl == null || imageUrl.isEmpty) continue;

        if (line.isNotEmpty) flushLine(null);
        buffer.write('\n\n![]($imageUrl)\n\n');
      }
    }

    if (line.isNotEmpty) flushLine(null);

    return buffer.toString().trim();
  }

  static String _inlineMarkdown(String text, Map<String, dynamic>? attributes) {
    if (attributes == null || attributes.isEmpty) return text;

    var result = text;

    if (attributes['code'] == true) {
      result = '`$result`';
    }
    if (attributes['bold'] == true || attributes['b'] == true) {
      result = '**$result**';
    }
    if (attributes['italic'] == true || attributes['i'] == true) {
      result = '_${result}_';
    }
    if (attributes['strike'] == true || attributes['s'] == true) {
      result = '~~$result~~';
    }
    if (attributes['link'] != null) {
      final link = attributes['link'].toString();
      result = '[$result]($link)';
    }

    return result;
  }

  static String _lineMarkdownPrefix(Map<String, dynamic>? attributes) {
    if (attributes == null || attributes.isEmpty) return '';

    // Quill обычно пишет {"header": 2}, а Fleather/Parchment —
    // {"heading": 2}. Поддерживаем оба формата.
    final header = attributes['header'] ?? attributes['heading'];
    if (header is int && header >= 1) {
      final level = header.clamp(1, 6);
      return '${'#' * level} ';
    }

    final indent = _parseIndent(attributes['indent']);
    final indentPrefix = '  ' * indent;

    // Quill: {"list": "bullet" | "ordered"};
    // Fleather/Parchment: {"block": "ul" | "ol" | "cl"}.
    final listType = attributes['list'];
    final blockType = attributes['block'];
    if (listType == 'bullet' || blockType == 'ul') return '$indentPrefix- ';
    if (listType == 'ordered' || blockType == 'ol') return '${indentPrefix}1. ';
    if (listType == 'checked' || blockType == 'cl') {
      final checked = attributes['checked'] == true ? 'x' : ' ';
      return '$indentPrefix- [$checked] ';
    }

    if (attributes['blockquote'] == true || blockType == 'quote') return '> ';
    if (attributes['code-block'] == true || blockType == 'code') {
      return '    ';
    }

    return '';
  }

  static int _parseIndent(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) return value < 0 ? 0 : value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _extractImageUrl(Map<dynamic, dynamic> insert) {
    dynamic imageData;

    if (insert.containsKey('image')) {
      imageData = insert['image'];
    } else if (insert['_type'] == 'image') {
      // Fleather block/inline embed: {"_type": "image", "source": "..."}
      imageData = insert;
    } else {
      return null;
    }

    String? imageUrl;

    if (imageData is String) {
      imageUrl = imageData;
    } else if (imageData is Map) {
      imageUrl = imageData['source'] as String?;
    }

    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    return ApiConfig.getMediaUrl(imageUrl);
  }

  /// Проверяет, является ли строка Delta JSON
  static bool isDeltaJson(String content) {
    if (content.isEmpty) return false;

    try {
      final json = jsonDecode(content);
      final ops = _extractOps(json);
      if (ops != null && ops.isNotEmpty) {
        final first = ops.first;
        return first is Map && first.containsKey('insert');
      }
    } catch (_) {
      // Не JSON
    }
    return false;
  }
}
