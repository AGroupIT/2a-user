# Точные цели экскурсии

Практика по `/training/assembly` дополнительно содержит 10 подсказок из `assembly_practice_steps.dart`. Используются обычный `TracksScreen` с локальными тестовыми данными и настоящий мастер. Выбор двух треков определяется по `assembly.selection.multiple`; заполнение полей переводит подсветку на существующую кнопку `assembly.wizard.ready.0/1/2`. Действия выполняет пользователь. Результат отправки появляется в обычном списке «Сборки». Отдельное представление учебной формы удалено.

56 шагов / 12 тем. Для действий подсвечиваются конкретные кнопки, поля и вкладки; для просмотра значения — само значение или название, а не площадь карточки. Возврат и перенос кода разделены; видео сборки имеет свой шаг.

Если цель скрыта в форме, показывается точный элемент подготовки с собственной инструкцией. После ручного открытия подсветка переключается на основную цель. Элементы скрытого за модальным окном экрана не используются. Если нужной записи/кнопки нет, остаётся пояснение и возможность пропустить шаг. Автоматических нажатий и отправок нет.

Для вкладок Организатора допустим дочерний маршрут `/sp-finance/purchases/:id`. Для сборки используются вкладки внутри уже открытого окна; переход назад к тарифу/упаковке указывает на существующую кнопку «Назад» формы.

Если предыдущая форма закрывает нужную кнопку трека, подсвечивается существующая ручка окна: потянуть вниз на мобильном экране или вправо при боковой навигации. После ручного закрытия подсветка переходит на нужную кнопку. Жест проверен на настоящем окне трека при ширине 390 и 1280 пикселей.

| Шаг | Маршрут входа | Точная цель |
| --- | --- | --- |
| `cabinet:0` | `/` | `nav.home` |
| `cabinet:1` | `/` | `nav.code` |
| `cabinet:2` | `/profile` | `profile.edit` |
| `cabinet:3` | `/` | `nav.notifications` |
| `warehouse:0` | `/` | `warehouse.copy-address` |
| `warehouse:1` | `/` | `warehouse.copy-phone` |
| `warehouse:2` | `/` | `warehouse.check` |
| `warehouse:3` | `/` | `warehouse.screenshot` |
| `tracks:0` | `/tracks` | `tracks.add.form` |
| `tracks:1` | `/tracks` | `track.status` |
| `tracks:2` | `/tracks` | `tracks.search` |
| `tracks:3` | `/tracks` | `track.product` |
| `track_actions:0` | `/tracks` | `track.open` |
| `track_actions:1` | `/photos` | `photos.open` |
| `track_actions:2` | `/tracks` | `track.question` |
| `track_actions:3` | `/tracks` | `track.return` |
| `track_actions:4` | `/tracks` | `track.transfer` |
| `assembly:0` | `/tracks` | `tracks.selection` |
| `assembly:1` | `/tracks` | `assembly.submit` |
| `assembly:2` | `/tracks` | `assembly.tariff` |
| `assembly:3` | `/tracks` | `assembly.packaging` |
| `assembly:4` | `/tracks` | `assembly.review` |
| `assembly:5` | `/tracks` | `assembly.open` |
| `tariffs:0` | `/tariffs` | `tariffs.name` |
| `tariffs:1` | `/calculator` | `calculator.weight` |
| `tariffs:2` | `/calculator` | `calculator.result` |
| `delivery:0` | `/tracks` | `assembly.tab.tracks` |
| `delivery:1` | `/tracks` | `assembly.tab.places` |
| `delivery:2` | `/tracks` | `assembly.tab.delivery` |
| `delivery:3` | `/tracks` | `assembly.status.details` |
| `delivery:4` | `/tracks` | `assembly.tab.video` |
| `payments:0` | `/invoices` | `invoice.amount` |
| `payments:1` | `/invoices` | `invoice.pay` |
| `payments:2` | `/payment-chat` | `payment.message` |
| `payments:3` | `/referral` | `referral.balance` |
| `self_buyout:0` | `/` | `menu.self-buyout` |
| `self_buyout:1` | `/self-buyout` | `selfbuyout.amount` |
| `self_buyout:2` | `/self-buyout` | `selfbuyout.requisites` |
| `self_buyout:3` | `/self-buyout` | `selfbuyout.terms` |
| `self_buyout:4` | `/self-buyout` | `selfbuyout.submit` |
| `self_buyout:5` | `/self-buyout` | `selfbuyout.request.open` |
| `self_buyout:6` | `/self-buyout` | `selfbuyout.request.status` |
| `purchases:0` | `/purchase-blanks` | `purchase.create` |
| `purchases:1` | `/shop` | `shop.product.open` |
| `purchases:2` | `/garage` | `garage.request.create` |
| `purchases:3` | `/purchase-blanks` | `purchase.request.open` |
| `organizer:0` | `/sp-finance` | `organizer.open` |
| `organizer:1` | `/sp-finance` | `organizer.tab.participants` |
| `organizer:2` | `/sp-finance` | `organizer.tab.finance` |
| `organizer:3` | `/sp-finance` | `organizer.tab.tracks` |
| `help:0` | `/partner-program` | `partner.invite` |
| `help:1` | `/search-nocode` | `nocode.search` |
| `help:2` | `/news` | `news.open` |
| `help:3` | `/rules` | `rules.open` |
| `help:4` | `/support` | `support.message` |
| `help:5` | `/` | `menu.report` |

## Проверка

Регрессионные widget-тесты сравнивают размеры целей возврата, переноса, оплаты, номера счёта, названия тарифа, QR-загрузки, условий, товара и партнёрского приглашения с размерами соответствующих реальных элементов. Проверены ручные callbacks, переключение с подготовительной кнопки на основную и допустимость дочерних маршрутов. Карта не содержит целей `route.*`, `legacy.*` или `*.card`.

Снимки `/Volumes/T7/2a-logistic/.omx/artifacts/training-precise/14-exact-return-button.png` и `15-exact-transfer-button.png` показывают настоящий ClientTrackCompactCard с вымышленной посылкой и настоящий TrainingTourHost. Реальные заявки в ходе проверки не создаются.
