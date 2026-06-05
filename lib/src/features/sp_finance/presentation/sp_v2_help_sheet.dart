import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/blurred_modal_bottom_sheet.dart';
import '../data/sp_v2_models.dart';
import 'sp_finance_ui.dart';

Future<void> showSpV2HelpSheet(BuildContext context) {
  return showBlurredModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const SpV2HelpSheet(),
  );
}

class SpV2HelpButton extends StatelessWidget {
  final VoidCallback onTap;

  const SpV2HelpButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 46,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                spreadRadius: -12,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.question_mark_rounded,
            size: 19,
            color: context.brandPrimary,
          ),
        ),
      ),
    );
  }
}

class SpV2HelpSheet extends StatelessWidget {
  const SpV2HelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 58,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE1E5ED),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SpAnimatedHeroSurface(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Icon(Icons.school_rounded, color: Colors.white, size: 36),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Как вести совместную покупку',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gilroy',
                              fontSize: 22,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Пошаговая инструкция для организатора СП',
                            style: TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontFamily: 'Gilroy',
                              fontSize: 13,
                              height: 1.22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: const [
                  _HelpPrincipleCard(),
                  SizedBox(height: 12),
                  _QuickFlowCard(),
                  SizedBox(height: 12),
                  _PurchaseFieldsCard(),
                  SizedBox(height: 12),
                  _ItemsAndCustomersCard(),
                  SizedBox(height: 12),
                  _PricesAndProfitCard(),
                  SizedBox(height: 12),
                  _DeliveryAndExpensesCard(),
                  SizedBox(height: 12),
                  _PaymentsCard(),
                  SizedBox(height: 12),
                  _TracksPhotosShippingCard(),
                  SizedBox(height: 12),
                  _StatusesCard(),
                  SizedBox(height: 12),
                  _ScenariosCard(),
                  SizedBox(height: 12),
                  _FinalChecklistCard(),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottomPadding),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Понятно'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpPrincipleCard extends StatelessWidget {
  const _HelpPrincipleCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.route_rounded,
      title: 'Главная идея раздела',
      subtitle:
          'СП — это не просто сборка, а полный процесс от заявки клиента до отправки ему товара.',
      children: const [
        _HelpBullet(
          'Одна совместная покупка объединяет клиентов, товары, фото, треки, оплаты, расходы и отправки клиентам.',
        ),
        _HelpBullet(
          'Каждый товар лучше заводить отдельно под конкретного клиента: даже если ссылка одна, размеры/цвет/количество и оплата могут отличаться.',
        ),
        _HelpBullet(
          'Трек номер привязывается опционально: если он известен — укажите его, тогда товар будет связан со складским треком и фотоотчётами.',
        ),
      ],
    );
  }
}

class _QuickFlowCard extends StatelessWidget {
  const _QuickFlowCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.timeline_rounded,
      title: 'Быстрый сценарий работы',
      subtitle: 'Если не хочется читать всё — начинайте по этой схеме.',
      children: const [
        _HelpStep(
          1,
          'Создайте СП',
          'Выберите валюту: юани, если закупаете в Китае, или рубли, если все цены уже в ₽.',
        ),
        _HelpStep(
          2,
          'Добавьте товары клиентов',
          'Для каждого клиента внесите товар, количество, ссылку/фото, параметры и цену выкупа.',
        ),
        _HelpStep(
          3,
          'Укажите цену клиента',
          'Можно вписать руками или массово рассчитать: без наценки, +%, фиксированная наценка.',
        ),
        _HelpStep(
          4,
          'Отмечайте выкуп',
          'После покупки нажимайте «Выкуплен». Если товар не купили — поставьте соответствующий статус.',
        ),
        _HelpStep(
          5,
          'Закройте приём товаров',
          'Когда новые позиции уже не принимаются, нажмите «Закрыть приём».',
        ),
        _HelpStep(
          6,
          'Привяжите треки',
          'Если есть трек номер из Китая — укажите его в товаре. Это свяжет товар со складским треком.',
        ),
        _HelpStep(
          7,
          'Посчитайте доставку и расходы',
          'После прибытия груза заполните вес, доставку СП, доставку клиенту и доп. расходы.',
        ),
        _HelpStep(
          8,
          'Отмечайте оплаты',
          'Товар, доставка и доп. расходы отмечаются отдельно — так видно, кто что уже оплатил.',
        ),
        _HelpStep(
          9,
          'Отправьте клиентам',
          'В карточке клиента укажите ТК, трек отправки, статус и комментарий по выдаче.',
        ),
      ],
    );
  }
}

class _PurchaseFieldsCard extends StatelessWidget {
  const _PurchaseFieldsCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.add_business_rounded,
      title: 'Создание СП и общие поля',
      subtitle: 'Эти настройки влияют на всю закупку.',
      children: const [
        _HelpField(
          'Название СП',
          'Понятное имя для себя: дата, категория, сезон или продавец.',
        ),
        _HelpField(
          'Комментарий',
          'Любая внутренняя заметка: условия, сроки, особенности выкупа.',
        ),
        _HelpField(
          'Валюта',
          'Глобальная валюта цен товара. CNY — цены выкупа и клиента вводятся в юанях. RUB — сразу в рублях.',
        ),
        _HelpField(
          'Курс юаня',
          'Нужен только для CNY. По нему приложение переводит товары в ₽ для оплат и финансов.',
        ),
        _HelpField(
          'Статус СП',
          'Показывает этап процесса: приём товаров, выкуп, путь, разбор, расчёт, сбор оплат, отправка.',
        ),
        _HelpField(
          'Приём товаров',
          'Когда приём закрыт, новые товары в эту СП добавлять нельзя. Используйте после дедлайна заказов.',
        ),
        _HelpNotice(
          'Совет',
          'Валюту лучше выбирать сразу правильно. Если уже внесли много товаров, смена логики валюты может запутать расчёты.',
          Icons.lightbulb_rounded,
        ),
      ],
    );
  }
}

class _ItemsAndCustomersCard extends StatelessWidget {
  const _ItemsAndCustomersCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.shopping_bag_rounded,
      title: 'Товары и клиенты',
      subtitle: 'Главная вкладка для ежедневной работы организатора.',
      children: const [
        _HelpField(
          'Клиент',
          'Можно выбрать существующего или создать нового прямо при добавлении товара.',
        ),
        _HelpField(
          'Контакты клиента',
          'ФИО, телефон, Telegram, WhatsApp, WeChat нужны, чтобы быстро написать или позвонить клиенту.',
        ),
        _HelpField(
          'Что купить',
          'Короткое название товара, чтобы быстро понимать позицию в списке.',
        ),
        _HelpField(
          'Количество',
          'Сколько штук этого товара нужно клиенту. Влияет на сумму товара и распределение по количеству.',
        ),
        _HelpField(
          'Ссылка на товар',
          'Ссылка кликабельна — можно открыть карточку продавца для проверки.',
        ),
        _HelpField(
          'Изображения товара',
          'Фото из WeChat/магазина. Помогают не потерять, какой товар заказал клиент.',
        ),
        _HelpField(
          'Данные продавца / параметры',
          'Размер, цвет, модель, объём, продавец, комментарии из переписки.',
        ),
        _HelpField(
          'Комментарий',
          'Внутренняя заметка по товару: что уточнить, что заменить, что проверить.',
        ),
        _HelpField(
          'Статус товара',
          'Отдельный статус позиции: запрошен, выкуплен, в пути, прибыл, отправлен клиенту и т.д.',
        ),
        _HelpField(
          'Перенести на клиента',
          'Если товар случайно завели не на того клиента, в редактировании можно поменять клиента.',
        ),
      ],
    );
  }
}

class _PricesAndProfitCard extends StatelessWidget {
  const _PricesAndProfitCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.payments_rounded,
      title: 'Цены, наценка и прибыль',
      subtitle: 'Раздел поддерживает разные модели заработка организатора.',
      children: const [
        _HelpField(
          'Цена выкупа за 1 шт.',
          'Сколько реально стоит одна единица товара для организатора.',
        ),
        _HelpField(
          'Цена клиента за 1 шт.',
          'Сколько клиент должен заплатить за одну единицу товара.',
        ),
        _HelpField(
          'Массовый расчёт цен',
          'Кнопка «Рассчитать цены клиента»: можно поставить цену клиента равной выкупу, +%, или +фиксированную сумму.',
        ),
        _HelpFormula(
          'Сумма товара',
          'Цена клиента × количество. Для CNY итог переводится в ₽ по курсу СП.',
        ),
        _HelpFormula(
          'Доход на товаре',
          '(Цена клиента − цена выкупа) × количество.',
        ),
        _HelpScenario(
          title: 'Скрытая наценка в товаре',
          text:
              'Товар стоит 100 ¥, клиенту показываете 130 ¥. Разница 30 ¥ × количество будет прибылью.',
        ),
        _HelpScenario(
          title: 'Без наценки на товар',
          text:
              'Цена клиента = цена выкупа. Тогда доход можно зафиксировать через доставку клиенту или отдельную комиссию, если вы её включили в цену.',
        ),
      ],
    );
  }
}

class _DeliveryAndExpensesCard extends StatelessWidget {
  const _DeliveryAndExpensesCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.local_shipping_rounded,
      title: 'Доставка и доп. расходы',
      subtitle:
          'Это самый важный блок после прибытия груза и разбора по клиентам.',
      children: const [
        _HelpField(
          'Фактический вес',
          'Реальный вес товара после разбора. Нужен для честного распределения доставки по весу.',
        ),
        _HelpField(
          'Доставка оплачена СП',
          'Себестоимость доставки для организатора: сколько реально заплатили за этот товар или долю товара.',
        ),
        _HelpField(
          'Доставка клиенту',
          'Сколько клиент должен оплатить за доставку. Эта сумма идёт в долг клиента.',
        ),
        _HelpFormula(
          'Доход на доставке',
          'Доставка клиенту − доставка оплачена СП.',
        ),
        _HelpField(
          'Массовый расчёт доставки',
          'Можно указать общую сумму, которую СП оплатил, и общую сумму, которую хотите выставить клиентам.',
        ),
        _HelpBullet(
          'Распределение по весу — лучший вариант, если товары перевзвешены.',
        ),
        _HelpBullet(
          'Поровну по клиентам — когда организатор делит доставку одинаково между участниками.',
        ),
        _HelpBullet(
          'Поровну по товарам — когда каждая позиция получает одинаковую долю.',
        ),
        _HelpBullet(
          'По количеству штук — когда важно количество единиц товара.',
        ),
        _HelpField(
          'Доп. расходы',
          'Бензин, терминал, переупаковка, доставка по городу и другие расходы сверх основной доставки.',
        ),
        _HelpBullet(
          'Доп. расходы можно распределить поровну, по весу, по количеству товаров или по сумме товаров.',
        ),
        _HelpNotice(
          'Важно',
          'Доп. расходы — это долг клиентов. В текущем расчёте прибыли они считаются как возмещение расходов, а не как отдельная прибыль.',
          Icons.warning_amber_rounded,
        ),
      ],
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.fact_check_rounded,
      title: 'Оплаты: товар, доставка, доп. расходы',
      subtitle:
          'Оплаты разделены специально, потому что клиенты часто платят частями.',
      children: const [
        _HelpField(
          'Товар оплачен',
          'Отмечает оплату именно за товары клиента.',
        ),
        _HelpField(
          'Доставка оплачена',
          'Отмечает оплату доставки отдельно от товара.',
        ),
        _HelpField(
          'Доп. расходы оплачены',
          'Отмечает оплату распределённых расходов: терминал, бензин, упаковка и т.д.',
        ),
        _HelpField(
          'Вкладка Клиенты',
          'Удобно отметить сразу все товары/доставку клиента как оплаченные.',
        ),
        _HelpField(
          'Вкладка Финансы',
          'Показывает начислено, оплачено и остаток по товарам, доставке и расходам.',
        ),
        _HelpScenario(
          title: 'Классический сценарий',
          text:
              'Сначала клиент оплачивает товар. После прибытия и расчёта веса вы выставляете доставку и отмечаете вторую оплату.',
        ),
      ],
    );
  }
}

class _TracksPhotosShippingCard extends StatelessWidget {
  const _TracksPhotosShippingCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.inventory_2_rounded,
      title: 'Треки, фото и отправка клиентам',
      subtitle: 'Связь товара со складом и финальная выдача клиенту.',
      children: const [
        _HelpField(
          'Трек номер',
          'Можно указать в товаре после выкупа. Если трек есть в системе, товар связывается со складским треком.',
        ),
        _HelpField(
          'Фото товара',
          'Фото, добавленные организатором, хранятся в карточке товара.',
        ),
        _HelpField(
          'Фотоотчёты склада',
          'Если товар связан с треком, можно ориентироваться на фотоотчёты склада по этому треку.',
        ),
        _HelpField(
          'Отправка клиенту',
          'В карточке клиента можно указать ТК, трек отправления, стоимость и комментарий.',
        ),
        _HelpField(
          'Статус отправки',
          'Черновик, готово к отправке, отправлено, доставлено или отменено.',
        ),
      ],
    );
  }
}

class _StatusesCard extends StatelessWidget {
  const _StatusesCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.flag_rounded,
      title: 'Статусы',
      subtitle:
          'Статусы не меняют деньги сами по себе, но помогают контролировать процесс.',
      children: [
        const _HelpSmallTitle('Статусы СП'),
        _HelpStatusWrap(
          statuses: SpV2PurchaseStatusInfo.all.map((status) => status.label),
        ),
        const SizedBox(height: 10),
        const _HelpSmallTitle('Статусы товара'),
        _HelpStatusWrap(
          statuses: SpV2ItemStatusInfo.all.map((status) => status.label),
        ),
        const SizedBox(height: 10),
        const _HelpSmallTitle('Статусы отправки клиенту'),
        _HelpStatusWrap(
          statuses: SpV2ShipmentStatusInfo.all.map((status) => status.label),
        ),
        const SizedBox(height: 10),
        const _HelpNotice(
          'Рекомендация',
          'Меняйте статусы сразу после действия: выкупили — «Выкуплен», груз едет — «В пути», разобрали — «Разобран». Так меньше путаницы с клиентами.',
          Icons.task_alt_rounded,
        ),
      ],
    );
  }
}

class _ScenariosCard extends StatelessWidget {
  const _ScenariosCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.account_tree_rounded,
      title: 'Частые варианты работы',
      subtitle:
          'Раздел специально сделан гибким под разные схемы организаторов.',
      children: const [
        _HelpScenario(
          title: 'Один товар для разных клиентов',
          text:
              'Создайте отдельную позицию под каждого клиента. Так у каждого будет своя оплата, размер, цвет, количество, фото и доставка.',
        ),
        _HelpScenario(
          title: 'Один товар, но разные размеры',
          text:
              'В названии или параметрах укажите размер/цвет, а товар всё равно заводите отдельной строкой.',
        ),
        _HelpScenario(
          title: 'Трек пока неизвестен',
          text:
              'Оставьте поле трека пустым. Его можно добавить позже в редактировании товара.',
        ),
        _HelpScenario(
          title: 'Не перевзвешиваете товары',
          text:
              'Используйте массовый расчёт доставки поровну по клиентам, товарам или количеству штук.',
        ),
        _HelpScenario(
          title: 'Перевзвешиваете после МСК',
          text:
              'Заполните фактический вес товаров и распределяйте доставку по весу — это самый понятный вариант для клиента.',
        ),
        _HelpScenario(
          title: 'Клиент оплатил всё сразу',
          text:
              'Отметьте товар, доставку и доп. расходы как оплаченные. Остаток по клиенту станет 0 ₽.',
        ),
        _HelpScenario(
          title: 'Товар не выкупился',
          text:
              'Поставьте статус «Не выкуплен» или «Отменён». При необходимости уберите цену клиента/итог, чтобы не было долга.',
        ),
      ],
    );
  }
}

class _FinalChecklistCard extends StatelessWidget {
  const _FinalChecklistCard();

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCard(
      icon: Icons.checklist_rounded,
      title: 'Чеклист перед завершением СП',
      subtitle:
          'Проверьте это, чтобы не потерять деньги и не запутать клиентов.',
      children: const [
        _HelpBullet('У всех товаров указан клиент и понятное название.'),
        _HelpBullet('Заполнены цена выкупа и цена клиента.'),
        _HelpBullet('Выкупленные товары отмечены как «Выкуплен».'),
        _HelpBullet('Треки привязаны там, где они известны.'),
        _HelpBullet('Фактический вес заполнен, если доставка делится по весу.'),
        _HelpBullet(
          'Доставка СП и доставка клиенту заполнены или рассчитаны массово.',
        ),
        _HelpBullet(
          'Общие доп. расходы внесены и распределены понятным способом.',
        ),
        _HelpBullet(
          'По каждому клиенту видно: товары, доставка, доп. расходы, оплачено и остаток.',
        ),
        _HelpBullet('Для отправленных клиентов указаны ТК и трек отправления.'),
      ],
    );
  }
}

class _HelpSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _HelpSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SpFinanceUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: context.brandPrimary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SpFinanceUi.sectionTitleStyle.copyWith(
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: SpFinanceUi.labelStyle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._withSpacing(children),
        ],
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> widgets) {
    final result = <Widget>[];
    for (var index = 0; index < widgets.length; index += 1) {
      if (index > 0) result.add(const SizedBox(height: 8));
      result.add(widgets[index]);
    }
    return result;
  }
}

class _HelpStep extends StatelessWidget {
  final int number;
  final String title;
  final String text;

  const _HelpStep(this.number, this.title, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SpFinanceUi.softDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: context.brandPrimary,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SpFinanceUi.sectionTitleStyle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(text, style: SpFinanceUi.labelStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpField extends StatelessWidget {
  final String name;
  final String description;

  const _HelpField(this.name, this.description);

  @override
  Widget build(BuildContext context) {
    return _HelpInlineCard(
      icon: Icons.label_important_rounded,
      title: name,
      text: description,
    );
  }
}

class _HelpBullet extends StatelessWidget {
  final String text;

  const _HelpBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 7, color: context.brandPrimary),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: SpFinanceUi.labelStyle)),
      ],
    );
  }
}

class _HelpFormula extends StatelessWidget {
  final String title;
  final String text;

  const _HelpFormula(this.title, this.text);

  @override
  Widget build(BuildContext context) {
    return _HelpInlineCard(
      icon: Icons.functions_rounded,
      title: title,
      text: text,
      accent: const Color(0xFF2563EB),
    );
  }
}

class _HelpScenario extends StatelessWidget {
  final String title;
  final String text;

  const _HelpScenario({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return _HelpInlineCard(
      icon: Icons.play_circle_rounded,
      title: title,
      text: text,
      accent: const Color(0xFF16A34A),
    );
  }
}

class _HelpNotice extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;

  const _HelpNotice(this.title, this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return _HelpInlineCard(
      icon: icon,
      title: title,
      text: text,
      accent: const Color(0xFFF97316),
    );
  }
}

class _HelpInlineCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color? accent;

  const _HelpInlineCard({
    required this.icon,
    required this.title,
    required this.text,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? context.brandPrimary;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(text, style: SpFinanceUi.labelStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSmallTitle extends StatelessWidget {
  final String text;

  const _HelpSmallTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: SpFinanceUi.sectionTitleStyle.copyWith(fontSize: 15),
    );
  }
}

class _HelpStatusWrap extends StatelessWidget {
  final Iterable<String> statuses;

  const _HelpStatusWrap({required this.statuses});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: statuses
          .map(
            (status) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: context.brandPrimary.withValues(alpha: 0.075),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: context.brandPrimary.withValues(alpha: 0.11),
                ),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: context.brandPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
