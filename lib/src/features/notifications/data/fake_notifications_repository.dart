import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification_item.dart';

Future<void> _latency() => Future<void>.microtask(() {});

abstract class NotificationsRepository {
  Future<List<NotificationItem>> fetchNotifications({
    required String clientCode,
  });
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return FakeNotificationsRepository();
});

class FakeNotificationsRepository implements NotificationsRepository {
  final Map<String, List<NotificationItem>> _cache = {};

  @override
  Future<List<NotificationItem>> fetchNotifications({
    required String clientCode,
  }) async {
    await _latency();
    final cached = _cache[clientCode];
    if (cached != null) return cached;

    final rng = Random(clientCode.hashCode ^ 0xBADC0DE);
    final now = DateTime.now();

    String trk() =>
        'TRK-${clientCode.replaceAll(' ', '')}-${100000 + rng.nextInt(900000)}';
    String asm() =>
        'ASM-${clientCode.replaceAll(' ', '')}-${1000 + rng.nextInt(9000)}';

    final trackStatuses = [
      'В ожидании',
      'Принят на склад',
      'На сборке',
      'Отправлен',
      'В пути',
      'Прибыл',
      'Получен',
    ];
    final assemblyStatuses = [
      'Формируется',
      'Готова к отправке',
      'Отправлена',
      'В пути',
      'Прибыла',
    ];
    final photoStatuses = [
      'Фото готово',
      'Видео готово',
      'Фото и видео готовы',
    ];

    final items = <NotificationItem>[];

    // Генерируем уведомления разных типов
    for (int i = 0; i < 20; i++) {
      final createdAt = now.subtract(
        Duration(hours: i * 4 + rng.nextInt(3), minutes: rng.nextInt(50)),
      );
      final isRead = rng.nextInt(4) == 0; // 25% прочитаны

      final typeIndex = rng.nextInt(7);

      switch (typeIndex) {
        case 0: // Track status
          final oldIdx = rng.nextInt(trackStatuses.length - 1);
          final newIdx =
              oldIdx + 1 + rng.nextInt(trackStatuses.length - oldIdx - 1);
          items.add(
            NotificationItem.trackStatusChange(
              id: 'n_track_${clientCode}_$i',
              trackNumber: trk(),
              oldStatus: trackStatuses[oldIdx],
              newStatus:
                  trackStatuses[newIdx.clamp(0, trackStatuses.length - 1)],
              createdAt: createdAt,
              isRead: isRead,
            ),
          );
          break;

        case 1: // Assembly status
          final oldIdx = rng.nextInt(assemblyStatuses.length - 1);
          final newIdx = oldIdx + 1;
          items.add(
            NotificationItem.assemblyStatusChange(
              id: 'n_asm_${clientCode}_$i',
              assemblyId: asm(),
              oldStatus: assemblyStatuses[oldIdx],
              newStatus:
                  assemblyStatuses[newIdx.clamp(
                    0,
                    assemblyStatuses.length - 1,
                  )],
              createdAt: createdAt,
              isRead: isRead,
            ),
          );
          break;

        case 2: // Photo report
          items.add(
            NotificationItem.photoReportStatusChange(
              id: 'n_photo_${clientCode}_$i',
              trackNumber: trk(),
              status: photoStatuses[rng.nextInt(photoStatuses.length)],
              createdAt: createdAt,
              isRead: isRead,
            ),
          );
          break;

        case 3: // Question answered
          final answers = [
            'Груз находится на таможенном оформлении',
            'Ожидается прибытие в течение 2-3 дней',
            'Документы приложены к грузу',
            'Перезвоните по телефону +7 (495) 123-45-67',
          ];
          items.add(
            NotificationItem.questionAnswered(
              id: 'n_question_${clientCode}_$i',
              trackNumber: trk(),
              answer: answers[rng.nextInt(answers.length)],
              createdAt: createdAt,
              isRead: isRead,
            ),
          );
          break;

        case 4: // Chat message
          final messages = [
            'Ваш груз готов к выдаче',
            'Пожалуйста, уточните адрес доставки',
            'Счёт на оплату отправлен на почту',
            'Есть уточнение по вашему заказу',
          ];
          items.add(
            NotificationItem.chatMessage(
              id: 'n_chat_${clientCode}_$i',
              senderName: 'Поддержка 2A',
              messagePreview: messages[rng.nextInt(messages.length)],
              createdAt: createdAt,
              isRead: isRead,
            ),
          );
          break;

        case 5: // News
          final newsTitles = [
            'Новые тарифы на доставку',
            'График работы в праздничные дни',
            'Открытие нового склада',
            'Обновление приложения',
          ];
          final newsIdx = rng.nextInt(newsTitles.length);
          items.add(
            NotificationItem.news(
              id: 'n_news_${clientCode}_$i',
              newsTitle: newsTitles[newsIdx],
              newsPreview: 'Подробнее читайте в разделе новостей...',
              newsId: 'news_$newsIdx',
              createdAt: createdAt,
              isRead: isRead,
            ),
          );
          break;

        case 6: // Invoice
          final amount = '${(rng.nextInt(900) + 100) * 100} ₽';
          items.add(
            NotificationItem.invoice(
              id: 'n_invoice_${clientCode}_$i',
              invoiceNumber: 'INV-${2400 + rng.nextInt(100)}',
              amount: amount,
              createdAt: createdAt,
              isRead: isRead,
            ),
          );
          break;
      }
    }

    // Сортируем по дате (новые первые)
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _cache[clientCode] = items;
    return items;
  }
}
