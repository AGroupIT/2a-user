// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<bool> copyText(String text) async {
  final body = html.document.body;
  if (body == null) return false;

  final textArea = html.TextAreaElement()
    ..value = text
    ..setAttribute('readonly', '')
    ..style.position = 'fixed'
    ..style.left = '-9999px'
    ..style.top = '0'
    ..style.opacity = '0';

  body.append(textArea);
  textArea.focus();
  textArea.select();

  try {
    return html.document.execCommand('copy');
  } catch (_) {
    return false;
  } finally {
    textArea.remove();
  }
}
