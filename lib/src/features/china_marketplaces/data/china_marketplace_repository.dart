import '../domain/china_marketplace_models.dart';

class ChinaMarketplaceSearchRequest {
  final ChinaMarketplace marketplace;
  final String query;
  final String? category;
  final MarketplaceCatalogFilter filter;
  final MarketplaceSortOption sort;

  const ChinaMarketplaceSearchRequest({
    required this.marketplace,
    required this.query,
    this.category,
    this.filter = MarketplaceCatalogFilter.all,
    this.sort = MarketplaceSortOption.popular,
  });
}

class ChinaMarketplaceImageSearchRequest {
  final ChinaMarketplace marketplace;
  final String imageFileName;
  final int imageSizeBytes;
  final String? category;
  final MarketplaceCatalogFilter filter;
  final MarketplaceSortOption sort;

  const ChinaMarketplaceImageSearchRequest({
    required this.marketplace,
    required this.imageFileName,
    required this.imageSizeBytes,
    this.category,
    this.filter = MarketplaceCatalogFilter.all,
    this.sort = MarketplaceSortOption.popular,
  });
}

/// Временный mock-репозиторий для frontend-only ветки.
///
/// Будущий backend должен заменить этот слой единым endpoint'ом-агрегатором:
/// search/detail/cart draft. На клиент НЕ должны попадать appSecret/signature,
/// токены площадок, Yandex GPT ключи и внутренние правила наценки.
class ChinaMarketplaceRepository {
  Future<MarketplaceProduct?> getById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  List<String> categoriesFor(ChinaMarketplace marketplace) {
    final categories =
        _products
            .where((item) => item.marketplace == marketplace)
            .map((item) => item.category)
            .toSet()
            .toList()
          ..sort();
    return categories;
  }

  Future<List<MarketplaceProduct>> search(
    ChinaMarketplaceSearchRequest request,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final query = request.query.trim().toLowerCase();
    var items = _products
        .where((item) => item.marketplace == request.marketplace)
        .toList(growable: false);

    final category = request.category?.trim();
    if (category != null && category.isNotEmpty) {
      items = items
          .where((item) => item.category == category)
          .toList(growable: false);
    }

    if (query.isNotEmpty) {
      items = items
          .where((item) {
            final attrs = item.attributes
                .map(
                  (attr) =>
                      '${attr.name} ${attr.value} ${attr.originalName} ${attr.originalValue}',
                )
                .join(' ');
            final text = [
              item.titleRu,
              item.originalTitle,
              item.sellerName,
              item.category,
              item.descriptionRu,
              attrs,
            ].join(' ').toLowerCase();
            return text.contains(query);
          })
          .toList(growable: false);
    }

    return _sortProducts(_applyFilter(items, request.filter), request.sort);
  }

  Future<List<MarketplaceProduct>> searchByImage(
    ChinaMarketplaceImageSearchRequest request,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));

    // Frontend-only mock: backend позже загрузит картинку, вызовет image-search
    // провайдера для 1688/Taobao, а для Pinduoduo сделает fallback через
    // распознавание + keyword search. На клиент возвращается тот же список.
    var items = _products
        .where((item) => item.marketplace == request.marketplace)
        .toList(growable: false);

    final category = request.category?.trim();
    if (category != null && category.isNotEmpty) {
      items = items
          .where((item) => item.category == category)
          .toList(growable: false);
    }

    return _sortProducts(_applyFilter(items, request.filter), request.sort);
  }

  List<MarketplaceProduct> _applyFilter(
    List<MarketplaceProduct> items,
    MarketplaceCatalogFilter filter,
  ) {
    switch (filter) {
      case MarketplaceCatalogFilter.all:
        return items;
      case MarketplaceCatalogFilter.topRated:
        return items
            .where((item) => item.rating >= 4.7)
            .toList(growable: false);
      case MarketplaceCatalogFilter.manyReviews:
        return items
            .where((item) => item.reviewCount >= 900)
            .toList(growable: false);
      case MarketplaceCatalogFilter.freeChinaDelivery:
        return items
            .where((item) => item.domesticDeliveryCny == 0)
            .toList(growable: false);
      case MarketplaceCatalogFilter.smallMinimum:
        return items
            .where((item) => item.minOrderQuantity <= 2)
            .toList(growable: false);
    }
  }

  List<MarketplaceProduct> _sortProducts(
    List<MarketplaceProduct> items,
    MarketplaceSortOption sort,
  ) {
    final result = [...items];
    result.sort((a, b) {
      switch (sort) {
        case MarketplaceSortOption.popular:
          final scoreA =
              (a.monthlySales / 10) + (a.rating * 100) + a.reviewCount;
          final scoreB =
              (b.monthlySales / 10) + (b.rating * 100) + b.reviewCount;
          return scoreB.compareTo(scoreA);
        case MarketplaceSortOption.priceAsc:
          return a.priceCny.compareTo(b.priceCny);
        case MarketplaceSortOption.priceDesc:
          return b.priceCny.compareTo(a.priceCny);
        case MarketplaceSortOption.rating:
          final rating = b.rating.compareTo(a.rating);
          if (rating != 0) return rating;
          return b.reviewCount.compareTo(a.reviewCount);
      }
    });
    return result;
  }
}

const _commonSku = [
  MarketplaceSkuOption(
    id: 'black-m',
    nameRu: 'Чёрный / M',
    originalName: '黑色 M',
  ),
  MarketplaceSkuOption(
    id: 'white-l',
    nameRu: 'Белый / L',
    originalName: '白色 L',
  ),
  MarketplaceSkuOption(
    id: 'gift-box',
    nameRu: 'Подарочная упаковка',
    originalName: '礼盒装',
    priceDeltaCny: 6,
  ),
];

const _shoeSku = [
  MarketplaceSkuOption(
    id: 'size-37-white',
    nameRu: '37 / белый',
    originalName: '37码 白色',
  ),
  MarketplaceSkuOption(
    id: 'size-38-black',
    nameRu: '38 / чёрный',
    originalName: '38码 黑色',
  ),
  MarketplaceSkuOption(
    id: 'size-39-beige',
    nameRu: '39 / бежевый',
    originalName: '39码 米色',
  ),
];

const _reviewsGood = [
  MarketplaceProductReview(
    author: 'Покупатель A***',
    rating: 5,
    text: 'Фото соответствует карточке, продавец быстро отправил заказ.',
    dateLabel: '2 недели назад',
  ),
  MarketplaceProductReview(
    author: 'Покупатель L***',
    rating: 4.8,
    text:
        'Качество хорошее, упаковку лучше дополнительно проверить перед отправкой.',
    dateLabel: 'месяц назад',
  ),
];

const _attrsBag = [
  MarketplaceProductAttribute(
    name: 'Материал',
    value: 'эко-кожа',
    originalName: '材质',
    originalValue: 'PU',
  ),
  MarketplaceProductAttribute(
    name: 'Размер',
    value: '32 × 26 × 12 см',
    originalName: '尺寸',
    originalValue: '32*26*12cm',
  ),
  MarketplaceProductAttribute(
    name: 'Цвета',
    value: 'чёрный, белый, бежевый',
    originalName: '颜色',
    originalValue: '黑/白/米',
  ),
];

const _attrsClothes = [
  MarketplaceProductAttribute(
    name: 'Состав',
    value: 'хлопок / полиэстер',
    originalName: '成分',
    originalValue: '棉/聚酯纤维',
  ),
  MarketplaceProductAttribute(
    name: 'Размеры',
    value: '90–140',
    originalName: '尺码',
    originalValue: '90-140',
  ),
  MarketplaceProductAttribute(
    name: 'Сезон',
    value: 'лето',
    originalName: '季节',
    originalValue: '夏季',
  ),
];

const _attrsElectronics = [
  MarketplaceProductAttribute(
    name: 'Питание',
    value: 'USB-C зарядка',
    originalName: '充电',
    originalValue: 'USB-C',
  ),
  MarketplaceProductAttribute(
    name: 'Комплектация',
    value: 'ночник, кабель, коробка',
    originalName: '包装',
    originalValue: '灯/线/盒',
  ),
  MarketplaceProductAttribute(
    name: 'Вес',
    value: 'около 120 г',
    originalName: '重量',
    originalValue: '约120g',
  ),
];

const _attrsShoe = [
  MarketplaceProductAttribute(
    name: 'Верх',
    value: 'текстиль / кожа PU',
    originalName: '鞋面',
    originalValue: '织物/PU',
  ),
  MarketplaceProductAttribute(
    name: 'Подошва',
    value: 'резина',
    originalName: '鞋底',
    originalValue: '橡胶',
  ),
  MarketplaceProductAttribute(
    name: 'Размеры',
    value: '35–40',
    originalName: '尺码',
    originalValue: '35-40',
  ),
];

const _attrsHome = [
  MarketplaceProductAttribute(
    name: 'Материал',
    value: 'пищевой пластик',
    originalName: '材质',
    originalValue: '食品级塑料',
  ),
  MarketplaceProductAttribute(
    name: 'Комплект',
    value: '3 контейнера',
    originalName: '套装',
    originalValue: '3件套',
  ),
  MarketplaceProductAttribute(
    name: 'Особенность',
    value: 'герметичная крышка',
    originalName: '特点',
    originalValue: '密封盖',
  ),
];

const _products = <MarketplaceProduct>[
  MarketplaceProduct(
    id: '1688-bag-01',
    marketplace: ChinaMarketplace.alibaba1688,
    externalId: 'offer-873625',
    originalTitle: '女士通勤托特包大容量厂家直供',
    titleRu: 'Женская сумка-тоут для работы, большая вместимость',
    descriptionRu:
        'Оптовая карточка 1688: несколько цветов, партия от 2 шт., менеджер проверит наличие и финальную цену.',
    sellerName: 'Guangzhou Factory Store',
    category: 'Сумки',
    externalUrl: 'https://www.1688.com/',
    priceCny: 42.6,
    domesticDeliveryCny: 8,
    minOrderQuantity: 2,
    monthlySales: 1240,
    rating: 4.8,
    reviewCount: 628,
    sellerRating: 4.9,
    sellerReviewCount: 12600,
    imageUrls: [
      'https://picsum.photos/seed/2a-bag-main/900/900',
      'https://picsum.photos/seed/2a-bag-detail/900/900',
      'https://picsum.photos/seed/2a-bag-inside/900/900',
    ],
    skuOptions: _commonSku,
    attributes: _attrsBag,
    reviews: _reviewsGood,
    imageSeed: 'bag',
  ),
  MarketplaceProduct(
    id: '1688-kids-02',
    marketplace: ChinaMarketplace.alibaba1688,
    externalId: 'offer-731902',
    originalTitle: '儿童夏季套装短袖短裤两件套',
    titleRu: 'Детский летний комплект: футболка и шорты',
    descriptionRu:
        'Размерный ряд, упаковка по цветам. Подходит для совместных покупок и мелкого опта.',
    sellerName: 'Yiwu Kids Apparel',
    category: 'Детская одежда',
    externalUrl: 'https://www.1688.com/',
    priceCny: 27.4,
    domesticDeliveryCny: 5,
    minOrderQuantity: 3,
    monthlySales: 4100,
    rating: 4.7,
    reviewCount: 1420,
    sellerRating: 4.8,
    sellerReviewCount: 21900,
    imageUrls: [
      'https://picsum.photos/seed/2a-kids-main/900/900',
      'https://picsum.photos/seed/2a-kids-set/900/900',
      'https://picsum.photos/seed/2a-kids-size/900/900',
    ],
    skuOptions: _commonSku,
    attributes: _attrsClothes,
    reviews: _reviewsGood,
    imageSeed: 'kids',
  ),
  MarketplaceProduct(
    id: '1688-led-03',
    marketplace: ChinaMarketplace.alibaba1688,
    externalId: 'offer-229104',
    originalTitle: '智能感应小夜灯USB充电跨境热卖',
    titleRu: 'Умный ночник с датчиком движения, USB зарядка',
    descriptionRu:
        'Нужно проверить комплектацию, тип вилки и упаковку перед выкупом.',
    sellerName: 'Shenzhen Smart Home',
    category: 'Электроника',
    externalUrl: 'https://www.1688.com/',
    priceCny: 18.8,
    domesticDeliveryCny: 4,
    minOrderQuantity: 5,
    monthlySales: 9850,
    rating: 4.6,
    reviewCount: 2380,
    sellerRating: 4.7,
    sellerReviewCount: 35600,
    imageUrls: [
      'https://picsum.photos/seed/2a-lamp-main/900/900',
      'https://picsum.photos/seed/2a-lamp-night/900/900',
      'https://picsum.photos/seed/2a-lamp-box/900/900',
    ],
    skuOptions: _commonSku,
    attributes: _attrsElectronics,
    reviews: _reviewsGood,
    imageSeed: 'lamp',
  ),
  MarketplaceProduct(
    id: 'taobao-shoes-01',
    marketplace: ChinaMarketplace.taobao,
    externalId: 'item-661287',
    originalTitle: '复古运动鞋女春秋厚底休闲鞋',
    titleRu: 'Женские ретро-кроссовки на высокой подошве',
    descriptionRu:
        'Розничная карточка Taobao. Менеджер уточнит размерную сетку, наличие и стоимость доставки по Китаю.',
    sellerName: 'Taobao Fashion Seller',
    category: 'Обувь',
    externalUrl: 'https://www.taobao.com/',
    priceCny: 144.5,
    domesticDeliveryCny: 10,
    monthlySales: 820,
    rating: 4.9,
    reviewCount: 946,
    sellerRating: 4.8,
    sellerReviewCount: 8900,
    imageUrls: [
      'https://picsum.photos/seed/2a-shoes-main/900/900',
      'https://picsum.photos/seed/2a-shoes-side/900/900',
      'https://picsum.photos/seed/2a-shoes-sole/900/900',
    ],
    skuOptions: _shoeSku,
    attributes: _attrsShoe,
    reviews: _reviewsGood,
    imageSeed: 'shoes',
  ),
  MarketplaceProduct(
    id: 'taobao-phone-02',
    marketplace: ChinaMarketplace.taobao,
    externalId: 'item-918245',
    originalTitle: '透明磁吸手机壳适用多型号',
    titleRu: 'Прозрачный магнитный чехол для телефона',
    descriptionRu:
        'Нужно выбрать модель телефона и цвет. Автоперевод сохраняет оригинальные SKU для менеджера.',
    sellerName: 'Digital Accessories CN',
    category: 'Аксессуары',
    externalUrl: 'https://www.taobao.com/',
    priceCny: 33.5,
    domesticDeliveryCny: 6,
    monthlySales: 6730,
    rating: 4.8,
    reviewCount: 3010,
    sellerRating: 4.9,
    sellerReviewCount: 41400,
    imageUrls: [
      'https://picsum.photos/seed/2a-case-main/900/900',
      'https://picsum.photos/seed/2a-case-magnet/900/900',
      'https://picsum.photos/seed/2a-case-package/900/900',
    ],
    skuOptions: _commonSku,
    attributes: _attrsElectronics,
    reviews: _reviewsGood,
    imageSeed: 'phone-case',
  ),
  MarketplaceProduct(
    id: 'taobao-cosmetics-03',
    marketplace: ChinaMarketplace.taobao,
    externalId: 'item-302701',
    originalTitle: '便携化妆刷套装柔软纤维毛',
    titleRu: 'Компактный набор мягких кистей для макияжа',
    descriptionRu:
        'Менеджер проверит ограничения по категории и возможность отправки.',
    sellerName: 'Beauty Life Taobao',
    category: 'Косметика',
    externalUrl: 'https://www.taobao.com/',
    priceCny: 50.4,
    domesticDeliveryCny: 7,
    monthlySales: 1350,
    rating: 4.7,
    reviewCount: 790,
    sellerRating: 4.7,
    sellerReviewCount: 7700,
    imageUrls: [
      'https://picsum.photos/seed/2a-cosmetics-main/900/900',
      'https://picsum.photos/seed/2a-cosmetics-kit/900/900',
      'https://picsum.photos/seed/2a-cosmetics-bag/900/900',
    ],
    skuOptions: _commonSku,
    attributes: _attrsBag,
    reviews: _reviewsGood,
    imageSeed: 'cosmetics',
  ),
  MarketplaceProduct(
    id: 'pdd-toy-01',
    marketplace: ChinaMarketplace.pinduoduo,
    externalId: 'goods-441928',
    originalTitle: '儿童益智积木大颗粒拼装玩具',
    titleRu: 'Детский развивающий конструктор с крупными деталями',
    descriptionRu:
        'Pinduoduo часто меняет акции и купоны — финальную цену подтвердит менеджер перед выкупом.',
    sellerName: 'PDD Toy Mall',
    category: 'Игрушки',
    externalUrl: 'https://www.pinduoduo.com/',
    priceCny: 22.3,
    domesticDeliveryCny: 0,
    monthlySales: 18400,
    rating: 4.5,
    reviewCount: 5200,
    sellerRating: 4.6,
    sellerReviewCount: 60100,
    imageUrls: [
      'https://picsum.photos/seed/2a-toy-main/900/900',
      'https://picsum.photos/seed/2a-toy-parts/900/900',
      'https://picsum.photos/seed/2a-toy-box/900/900',
    ],
    skuOptions: _commonSku,
    attributes: _attrsHome,
    reviews: _reviewsGood,
    imageSeed: 'toy',
  ),
  MarketplaceProduct(
    id: 'pdd-home-02',
    marketplace: ChinaMarketplace.pinduoduo,
    externalId: 'goods-555013',
    originalTitle: '厨房密封收纳罐透明防潮',
    titleRu: 'Прозрачные кухонные контейнеры для хранения',
    descriptionRu:
        'Подходит для набора корзины. Менеджер проверит размер, комплектность и риск повреждения.',
    sellerName: 'PDD Home Goods',
    category: 'Для дома',
    externalUrl: 'https://www.pinduoduo.com/',
    priceCny: 14.3,
    domesticDeliveryCny: 3,
    monthlySales: 22100,
    rating: 4.6,
    reviewCount: 7600,
    sellerRating: 4.8,
    sellerReviewCount: 73000,
    imageUrls: [
      'https://picsum.photos/seed/2a-storage-main/900/900',
      'https://picsum.photos/seed/2a-storage-set/900/900',
      'https://picsum.photos/seed/2a-storage-kitchen/900/900',
    ],
    skuOptions: _commonSku,
    attributes: _attrsHome,
    reviews: _reviewsGood,
    imageSeed: 'storage',
  ),
  MarketplaceProduct(
    id: 'pdd-textile-03',
    marketplace: ChinaMarketplace.pinduoduo,
    externalId: 'goods-732118',
    originalTitle: '纯棉浴巾柔软吸水家用',
    titleRu: 'Мягкое хлопковое полотенце для дома',
    descriptionRu:
        'Можно добавить несколько цветов в корзину и оставить комментарий менеджеру.',
    sellerName: 'PDD Textile Store',
    category: 'Текстиль',
    externalUrl: 'https://www.pinduoduo.com/',
    priceCny: 29.8,
    domesticDeliveryCny: 4,
    monthlySales: 9600,
    rating: 4.7,
    reviewCount: 1880,
    sellerRating: 4.7,
    sellerReviewCount: 19600,
    imageUrls: [
      'https://picsum.photos/seed/2a-towel-main/900/900',
      'https://picsum.photos/seed/2a-towel-detail/900/900',
      'https://picsum.photos/seed/2a-towel-colors/900/900',
    ],
    skuOptions: _commonSku,
    attributes: _attrsHome,
    reviews: _reviewsGood,
    imageSeed: 'towel',
  ),
];
