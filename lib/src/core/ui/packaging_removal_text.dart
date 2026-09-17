import 'package:flutter/widgets.dart';

import '../models/packaging_removal.dart';
import '../utils/locale_text.dart';

String packagingRemovalLabel(
  BuildContext context,
  PackagingRemovalOption option,
) => switch (option) {
  PackagingRemovalOption.none => tr(context, ru: 'Не снимать', zh: '不拆除包装'),
  PackagingRemovalOption.transportOnly => tr(
    context,
    ru: 'Только транспортировочную',
    zh: '仅拆除运输包装',
  ),
  PackagingRemovalOption.boxOnly => tr(
    context,
    ru: 'Удалить коробку',
    zh: '拆除盒子包装',
  ),
  PackagingRemovalOption.bagOnly => tr(
    context,
    ru: 'Снять упаковку с сумки',
    zh: '拆除袋子包装',
  ),
  PackagingRemovalOption.all => tr(
    context,
    ru: 'Удалить всю упаковку',
    zh: '拆除全部包装',
  ),
};

String packagingRemovalDescription(
  BuildContext context,
  PackagingRemovalOption option,
) => switch (option) {
  PackagingRemovalOption.none => tr(
    context,
    ru: 'Упаковка сохраняется.',
    zh: '保留包装。',
  ),
  PackagingRemovalOption.boxOnly => tr(
    context,
    ru: 'Удаляем только коробку. Упаковку с сумки и другие виды упаковки не снимаем.',
    zh: '仅拆除盒子包装，保留袋子包装及其他包装。',
  ),
  PackagingRemovalOption.bagOnly => tr(
    context,
    ru: 'Снимаем только упаковку с сумки. Коробку и другие виды упаковки не снимаем.',
    zh: '仅拆除袋子包装，保留盒子包装及其他包装。',
  ),
  PackagingRemovalOption.transportOnly => tr(
    context,
    ru: 'Снимаем только транспортировочную упаковку: внешние коробки/мешки продавца, лишний скотч и мятый картон. Заводскую/розничную упаковку товара не вскрываем.',
    zh: '仅拆除运输包装：卖家的外箱或外袋、多余胶带和破损纸板，不拆开商品的原厂或零售包装。',
  ),
  PackagingRemovalOption.all => tr(
    context,
    ru: 'Снимаем всю упаковку, которую можно безопасно снять: транспортировочную, внешнюю, заводскую/розничную и внутренние защитные материалы. Товар может остаться без оригинальной упаковки.',
    zh: '在不损坏商品的前提下拆除所有包装，包括运输、外层、原厂或零售包装及内部保护材料。商品可能不再保留原包装。',
  ),
};

String packagingRemovalTargetsUnavailableText(BuildContext context) => tr(
  context,
  ru: 'Отдельный выбор коробки или сумки станет доступен после обновления сервиса. Сейчас можно выбрать прежние варианты снятия упаковки.',
  zh: '服务更新后可分别选择拆除盒子或袋子包装。目前可使用原有的拆包装选项。',
);
