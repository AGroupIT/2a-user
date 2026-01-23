import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Виджет для отображения Quill Delta JSON контента
class QuillDeltaViewer extends StatelessWidget {
  final String jsonContent;
  final TextStyle? baseTextStyle;
  final Color? linkColor;
  final Function(String)? onImageTap;

  const QuillDeltaViewer({
    super.key,
    required this.jsonContent,
    this.baseTextStyle,
    this.linkColor,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = baseTextStyle ??
        const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Color(0xFF333333),
        );

    final defaultLinkColor = linkColor ?? Theme.of(context).primaryColor;

    try {
      // Парсим JSON
      final dynamic parsed = jsonDecode(jsonContent);

      // Quill Delta может быть либо массивом ops, либо объектом с полем ops
      final List<dynamic> ops;
      if (parsed is Map && parsed.containsKey('ops')) {
        ops = parsed['ops'] as List<dynamic>;
      } else if (parsed is List) {
        ops = parsed;
      } else {
        // Если это не Quill Delta, показываем как обычный текст
        return SelectableText(
          jsonContent,
          style: defaultTextStyle,
        );
      }

      return _buildDeltaContent(ops, defaultTextStyle, defaultLinkColor);
    } catch (e) {
      // Если парсинг не удался, показываем как обычный текст
      return SelectableText(
        jsonContent,
        style: defaultTextStyle,
      );
    }
  }

  Widget _buildDeltaContent(
    List<dynamic> ops,
    TextStyle baseStyle,
    Color linkColor,
  ) {
    final List<Widget> widgets = [];
    final List<InlineSpan> currentParagraph = [];

    for (final op in ops) {
      if (op is! Map) continue;

      final insert = op['insert'];
      final attributes = op['attributes'] as Map<String, dynamic>?;

      if (insert is String) {
        // Текстовый контент
        final lines = insert.split('\n');

        for (int i = 0; i < lines.length; i++) {
          if (lines[i].isNotEmpty) {
            currentParagraph.add(_buildTextSpan(
              lines[i],
              attributes,
              baseStyle,
              linkColor,
            ));
          }

          // Новая строка - сохраняем параграф
          if (i < lines.length - 1) {
            if (currentParagraph.isNotEmpty) {
              widgets.add(_buildParagraphWidget(
                currentParagraph.toList(),
                attributes,
                baseStyle,
              ));
              currentParagraph.clear();
            }
          }
        }
      } else if (insert is Map) {
        // Встроенный контент (изображение, видео и т.д.)
        if (currentParagraph.isNotEmpty) {
          widgets.add(_buildParagraphWidget(
            currentParagraph.toList(),
            null,
            baseStyle,
          ));
          currentParagraph.clear();
        }

        if (insert.containsKey('image')) {
          widgets.add(_buildImage(insert['image'] as String));
        }
      }
    }

    // Добавляем последний параграф
    if (currentParagraph.isNotEmpty) {
      widgets.add(_buildParagraphWidget(
        currentParagraph.toList(),
        null,
        baseStyle,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  InlineSpan _buildTextSpan(
    String text,
    Map<String, dynamic>? attributes,
    TextStyle baseStyle,
    Color linkColor,
  ) {
    TextStyle style = baseStyle;

    if (attributes != null) {
      // Bold
      if (attributes['bold'] == true || attributes['b'] == true) {
        style = style.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A));
      }

      // Italic
      if (attributes['italic'] == true || attributes['i'] == true) {
        style = style.copyWith(fontStyle: FontStyle.italic, color: const Color(0xFF444444));
      }

      // Underline
      if (attributes['underline'] == true || attributes['u'] == true) {
        style = style.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFF2196F3),
          decorationThickness: 2,
        );
      }

      // Strike
      if (attributes['strike'] == true || attributes['s'] == true) {
        style = style.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: const Color(0xFF999999),
          decorationThickness: 2,
          color: const Color(0xFF999999),
        );
      }

      // Link
      if (attributes['link'] != null) {
        final url = attributes['link'] as String;
        style = style.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
        );

        return TextSpan(
          text: text,
          style: style,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            },
        );
      }

      // Color
      if (attributes['color'] != null) {
        final colorStr = attributes['color'] as String;
        final color = _parseColor(colorStr);
        if (color != null) {
          style = style.copyWith(color: color);
        }
      }

      // Background color
      if (attributes['background'] != null) {
        final colorStr = attributes['background'] as String;
        final color = _parseColor(colorStr);
        if (color != null) {
          style = style.copyWith(backgroundColor: color);
        }
      }

      // Code
      if (attributes['code'] == true) {
        style = style.copyWith(
          fontFamily: 'monospace',
          backgroundColor: const Color(0xFFF5F5F5),
          color: const Color(0xFFe53935),
        );
      }

      // Header
      if (attributes['header'] != null) {
        final level = attributes['header'];
        if (level == 1) {
          style = style.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.3,
          );
        } else if (level == 2) {
          style = style.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.3,
          );
        } else if (level == 3) {
          style = style.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.3,
          );
        }
      }
    }

    return TextSpan(text: text, style: style);
  }

  Widget _buildParagraphWidget(
    List<InlineSpan> spans,
    Map<String, dynamic>? attributes,
    TextStyle baseStyle,
  ) {
    EdgeInsets padding = const EdgeInsets.only(bottom: 12);
    Widget? leading;

    // Проверяем атрибуты параграфа
    if (attributes != null) {
      // Header
      if (attributes['header'] != null) {
        final level = attributes['header'];
        if (level == 1) {
          padding = const EdgeInsets.only(top: 16, bottom: 8);
        } else if (level == 2) {
          padding = const EdgeInsets.only(top: 14, bottom: 6);
        } else if (level == 3) {
          padding = const EdgeInsets.only(top: 12, bottom: 6);
        }
      }

      // List
      if (attributes['list'] == 'bullet') {
        leading = Padding(
          padding: const EdgeInsets.only(right: 8, top: 2),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF2196F3),
              shape: BoxShape.circle,
            ),
          ),
        );
      } else if (attributes['list'] == 'ordered') {
        leading = Padding(
          padding: const EdgeInsets.only(right: 8, top: 2),
          child: Text(
            '1.',
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2196F3),
            ),
          ),
        );
      }

      // Blockquote
      if (attributes['blockquote'] == true) {
        return Container(
          margin: padding,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            border: const Border(
              left: BorderSide(color: Color(0xFF2196F3), width: 4),
            ),
            color: const Color(0xFFFFF5F3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText.rich(
            TextSpan(children: spans),
          ),
        );
      }

      // Code block
      if (attributes['code-block'] == true) {
        return Container(
          margin: padding,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText.rich(
            TextSpan(
              children: spans,
              style: baseStyle.copyWith(fontFamily: 'monospace'),
            ),
          ),
        );
      }
    }

    // Обычный параграф или список
    if (leading != null) {
      return Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            Expanded(
              child: SelectableText.rich(
                TextSpan(children: spans),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: SelectableText.rich(
        TextSpan(children: spans),
      ),
    );
  }

  Widget _buildImage(String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: onImageTap != null ? () => onImageTap!(url) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              height: 150,
              color: const Color(0xFFF5F5F5),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, _, _) => Container(
              height: 150,
              color: const Color(0xFFF5F5F5),
              child: const Icon(
                Icons.broken_image_rounded,
                color: Color(0xFFCCCCCC),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? _parseColor(String colorStr) {
    try {
      // Поддержка HEX цветов (#RRGGBB или RRGGBB)
      String hex = colorStr.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // Добавляем альфа-канал
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return null;
    }
  }
}
