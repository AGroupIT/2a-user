import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/news_item.dart';

abstract class NewsRepository {
  Future<List<NewsItem>> fetchNews();
  Future<NewsItem?> getBySlug(String slug);
}

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return FakeNewsRepository();
});

final newsListProvider = FutureProvider<List<NewsItem>>((ref) async {
  final repo = ref.watch(newsRepositoryProvider);
  return repo.fetchNews();
});

final newsItemProvider = FutureProvider.family<NewsItem?, String>((ref, slug) async {
  final repo = ref.watch(newsRepositoryProvider);
  return repo.getBySlug(slug);
});

class FakeNewsRepository implements NewsRepository {
  static final _items = <NewsItem>[
    NewsItem(
      slug: 'welcome',
      title: 'Добро пожаловать в 2A Logistic',
      excerpt: 'Мы обновили личный кабинет и готовим мобильное приложение.',
      imageUrl: 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800',
      content: '''
Мы рады представить вам **обновлённый личный кабинет** и анонсировать выход мобильного приложения!

## Что нового?

### Улучшенный интерфейс
- Современный дизайн с удобной навигацией
- Быстрый доступ ко всем функциям
- Адаптивная верстка для любых устройств

### Новые возможности
1. Улучшенная работа с **фотоотчётами**
2. Push-уведомления о статусе грузов
3. Чат с поддержкой прямо в приложении

> Мы стремимся сделать работу с грузами максимально удобной для вас!

---

Следите за обновлениями и не забудьте [подписаться на наш Telegram](https://t.me/twoa_logistics).

*Спасибо, что вы с нами!*
''',
      publishedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    NewsItem(
      slug: 'pwa-tips',
      title: 'Подсказки по работе с фотоотчётами',
      excerpt: 'Как быстро найти нужные фото и отфильтровать по треку.',
      imageUrl: 'https://images.unsplash.com/photo-1553413077-190dd305871c?w=800',
      content: '''
## Как работать с фотоотчётами

Фотоотчёты — важный инструмент для контроля состояния ваших грузов. Вот несколько полезных советов:

### Поиск фото

1. Откройте вкладку **Фото**
2. Введите трек-номер в поле поиска
3. Нажмите на фото, чтобы открыть просмотр

### Фильтрация

Вы можете фильтровать фото по:
- Дате загрузки
- Статусу груза
- Типу фото (упаковка, содержимое, повреждения)

> **Важно:** Если фото ещё не появилось — попробуйте позже. Выгрузка может занять некоторое время.

### Скачивание

Для скачивания фото:
1. Откройте нужное изображение
2. Нажмите кнопку ~~сохранить~~ **Скачать**
3. Выберите папку для сохранения

---

Если у вас возникли вопросы, обратитесь в [поддержку](https://t.me/twoa_manager).
''',
      publishedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    NewsItem(
      slug: 'new-features-2024',
      title: 'Обновление функционала — декабрь 2024',
      excerpt: 'Добавлены новые статусы, улучшен поиск и многое другое.',
      content: '''
## Декабрьское обновление

Мы продолжаем улучшать сервис для вас. Вот что нового:

### Новые статусы грузов

| Статус | Описание |
|--------|----------|
| На складе | Груз принят на склад в Китае |
| Отправлен | Груз отправлен в Россию |
| На терминале | Груз прибыл на терминал |
| К выдаче | Готов к получению |

### Улучшенный поиск

Теперь поиск работает **быстрее** и поддерживает:
- Поиск по последним цифрам трека
- Поиск по частичному совпадению
- Глобальный поиск по всем кодам клиента

### Что планируется

- [ ] Уведомления в Telegram
- [ ] Калькулятор доставки
- [ ] История изменений статусов

*Следите за новостями!*
''',
      publishedAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  @override
  Future<List<NewsItem>> fetchNews() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final sorted = [..._items]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return sorted;
  }

  @override
  Future<NewsItem?> getBySlug(String slug) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    try {
      return _items.firstWhere((i) => i.slug == slug);
    } catch (_) {
      return null;
    }
  }
}

