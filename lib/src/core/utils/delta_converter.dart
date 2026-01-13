import 'dart:convert';

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
      if (json is List) {
        return _extractTextFromDelta(json);
      }
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
      if (json is List) {
        return _convertDeltaToMarkdown(json);
      }
    } catch (_) {
      // Не JSON - возвращаем как есть
    }
    return content;
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
  
  /// Конвертирует Delta в Markdown с поддержкой форматирования
  static String _convertDeltaToMarkdown(List<dynamic> operations) {
    final buffer = StringBuffer();
    String? pendingLineFormat;
    
    for (int i = 0; i < operations.length; i++) {
      final op = operations[i];
      if (op is! Map || !op.containsKey('insert')) continue;
      
      final insert = op['insert'];
      final attributes = op['attributes'] as Map<String, dynamic>?;
      
      if (insert is String) {
        String text = insert;
        
        // Применяем inline форматирование
        if (attributes != null) {
          // Заголовки (применяются к строке, заканчивающейся \n)
          if (attributes.containsKey('header')) {
            final level = attributes['header'] as int? ?? 1;
            pendingLineFormat = '${'#' * level} ';
          }
          
          // Списки
          if (attributes.containsKey('list')) {
            final listType = attributes['list'];
            if (listType == 'bullet') {
              pendingLineFormat = '- ';
            } else if (listType == 'ordered') {
              pendingLineFormat = '1. ';
            }
          }
          
          // Bold
          if (attributes['bold'] == true) {
            text = '**$text**';
          }
          
          // Italic
          if (attributes['italic'] == true) {
            text = '_${text}_';
          }
          
          // Code
          if (attributes['code'] == true) {
            text = '`$text`';
          }
          
          // Link
          if (attributes.containsKey('link')) {
            final link = attributes['link'] as String;
            text = '[$text]($link)';
          }
        }
        
        // Обрабатываем переносы строк
        final lines = text.split('\n');
        for (int j = 0; j < lines.length; j++) {
          final line = lines[j];
          
          // Применяем форматирование строки в начале
          if (pendingLineFormat != null && line.isNotEmpty) {
            buffer.write(pendingLineFormat);
            pendingLineFormat = null;
          }
          
          buffer.write(line);
          
          // Добавляем перенос строки, кроме последнего элемента
          if (j < lines.length - 1) {
            buffer.write('\n');
          }
        }
      } else if (insert is Map) {
        // Embed объекты
        // Fleather использует формат: {"image": {"source": "url"}}
        // или просто {"image": "url"}
        if (insert.containsKey('image')) {
          final imageData = insert['image'];
          String? imageUrl;
          
          if (imageData is String) {
            imageUrl = imageData;
          } else if (imageData is Map) {
            imageUrl = imageData['source'] as String?;
          }
          
          if (imageUrl != null && imageUrl.isNotEmpty) {
            buffer.write('\n\n![]($imageUrl)\n\n');
          }
        }
      }
    }
    
    return buffer.toString().trim();
  }
  
  /// Проверяет, является ли строка Delta JSON
  static bool isDeltaJson(String content) {
    if (content.isEmpty) return false;
    
    try {
      final json = jsonDecode(content);
      if (json is List && json.isNotEmpty) {
        final first = json.first;
        return first is Map && first.containsKey('insert');
      }
    } catch (_) {
      // Не JSON
    }
    return false;
  }
}
