import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/news/domain/news_item.dart';

void main() {
  group('NewsItem.fromJson', () {
    test('builds excerpt from Quill Delta plain text and keeps raw content', () {
      const rawDelta =
          '[{"insert":"📸 Фотоотчёт: важная информация\\n\\nДля корректного выполнения фотоотчёта просим вас максимально чётко прописывать пожелания."}]';

      final item = NewsItem.fromJson({
        'id': 42,
        'title': 'Фотоотчет',
        'content': rawDelta,
        'createdAt': '2026-04-25T12:00:00.000Z',
      });

      expect(item.content, rawDelta);
      expect(item.excerpt, isNot(contains('[{"insert"')));
      expect(item.excerpt, contains('Фотоотчёт: важная информация'));
      expect(item.excerpt, contains('Для корректного выполнения'));
    });
  });
}
