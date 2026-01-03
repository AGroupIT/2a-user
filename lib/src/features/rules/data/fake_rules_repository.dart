import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rule_item.dart';

abstract class RulesRepository {
  Future<List<RuleItem>> fetchRules();
  Future<RuleItem?> getBySlug(String slug);
}

final rulesRepositoryProvider = Provider<RulesRepository>((ref) {
  return FakeRulesRepository();
});

final rulesListProvider = FutureProvider<List<RuleItem>>((ref) async {
  final repo = ref.watch(rulesRepositoryProvider);
  return repo.fetchRules();
});

final ruleItemProvider = FutureProvider.family<RuleItem?, String>((ref, slug) async {
  final repo = ref.watch(rulesRepositoryProvider);
  return repo.getBySlug(slug);
});

class FakeRulesRepository implements RulesRepository {
  static final _items = <RuleItem>[
    const RuleItem(
      slug: 'general',
      title: 'Общие правила',
      excerpt: 'Основные положения и условия работы с сервисом 2A Logistic.',
      order: 1,
      content: '''
## Общие положения

Настоящие правила регулируют порядок оказания услуг по доставке грузов из Китая.

### Основные условия

1. Клиент обязуется предоставлять **достоверную информацию** о грузе
2. Компания не несёт ответственности за содержимое посылок
3. Срок хранения груза на складе — **30 дней**

> Внимательно читайте правила перед отправкой груза!

### Запрещённые товары

К перевозке **не принимаются**:
- Оружие и боеприпасы
- Наркотические вещества
- Контрафактная продукция
- Скоропортящиеся продукты

---

При возникновении вопросов обращайтесь в поддержку.
''',
    ),
    const RuleItem(
      slug: 'photo-reports',
      title: 'Фотоотчёты',
      excerpt: 'Правила работы с фотоотчётами и сроки их появления.',
      order: 2,
      content: '''
## Фотоотчёты

Фотоотчёты — это фотографии вашего груза, сделанные на нашем складе.

### Когда появляются фото

| Этап | Срок появления |
|------|---------------|
| Приёмка на склад | 1-2 рабочих дня |
| Упаковка | В течение 24 часов |
| Отправка | Сразу после формирования |

### Виды фотоотчётов

1. **Фото при приёмке** — общий вид груза
2. **Фото содержимого** — по запросу клиента
3. **Фото упаковки** — перед отправкой

> Если фото ещё нет — попробуйте позже. Выгрузка может занять время.

### Как заказать дополнительное фото

- Перейдите в раздел *Треки*
- Выберите нужный трек
- Нажмите **Запросить фото**
- Опишите, что нужно сфотографировать

Стоимость услуги — согласно тарифам.
''',
    ),
    const RuleItem(
      slug: 'support',
      title: 'Поддержка',
      excerpt: 'Как связаться с поддержкой и получить помощь.',
      order: 3,
      content: '''
## Служба поддержки

Мы всегда готовы помочь вам с любыми вопросами!

### Способы связи

- **Чат в приложении** — самый быстрый способ
- **Telegram** — @twoa_manager
- **Email** — support@2a-logistics.ru

### Время работы

| День | Часы работы |
|------|-------------|
| Пн-Пт | 09:00 - 21:00 (МСК) |
| Сб | 10:00 - 18:00 (МСК) |
| Вс | Выходной |

### Частые вопросы

**Как узнать статус груза?**
> Перейдите в раздел «Треки» и введите номер отслеживания

**Сколько стоит доставка?**
> Стоимость рассчитывается индивидуально. Обратитесь к менеджеру.

**Как оплатить счёт?**
> Откройте раздел «Счета» и нажмите кнопку оплаты

---

*Среднее время ответа — 15 минут в рабочее время.*
''',
    ),
    const RuleItem(
      slug: 'payment',
      title: 'Оплата услуг',
      excerpt: 'Способы оплаты, сроки и правила возврата.',
      order: 4,
      content: '''
## Оплата услуг

### Способы оплаты

Мы принимаем следующие способы оплаты:

1. **Банковская карта** — Visa, MasterCard, МИР
2. **Банковский перевод** — для юридических лиц
3. **СБП** — Система Быстрых Платежей

### Сроки оплаты

- Счёт должен быть оплачен в течение **7 дней**
- При просрочке начисляется пеня — *0.1% в день*
- Груз выдаётся только после полной оплаты

> **Важно:** Сохраняйте чеки об оплате до получения груза

### Возврат средств

Возврат возможен в следующих случаях:
- Двойная оплата
- Отмена заказа до отправки
- Ошибка в расчёте

Срок возврата — до 10 рабочих дней.

---

По вопросам оплаты обращайтесь в бухгалтерию: billing@2a-logistics.ru
''',
    ),
  ];

  @override
  Future<List<RuleItem>> fetchRules() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final sorted = [..._items]..sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }

  @override
  Future<RuleItem?> getBySlug(String slug) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    try {
      return _items.firstWhere((i) => i.slug == slug);
    } catch (_) {
      return null;
    }
  }
}
