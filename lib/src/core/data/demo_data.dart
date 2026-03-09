import '../../features/assemblies/domain/box.dart';
import '../../features/invoices/domain/invoice_item.dart';
import '../../features/photos/domain/photo_item.dart';
import '../../features/rules/domain/rule_item.dart';
import '../../features/sp_finance/data/sp_models.dart';
import '../../features/tracks/domain/track_item.dart';

/// Статичные демо-данные для режима обучения.
abstract class DemoData {
  static final _now = DateTime.now();

  // ── Демо-сборка ───────────────────────────────────────────────────────────

  static final _demoAssembly = TrackAssembly(
    id: 501,
    number: 'A-2025-0501',
    name: 'Демо сборка',
    status: 'shipped',
    statusName: 'Отправлена',
    statusColor: '2563EB',
    tariffName: 'Стандарт',
    tariffCost: 18.5,
    packagingTypes: ['Стрейч плёнка', 'Пузырчатая плёнка'],
    packagingCost: 3.0,
    hasInsurance: false,
    deliveryMethod: 'transport_company',
    transportCompanyName: 'СДЭК',
    recipientName: 'Иван Иванов',
    recipientPhone: '+7 900 123-45-67',
    recipientCity: 'Москва',
    boxes: [
      Box(
        id: 101,
        number: 1,
        height: 50,
        width: 40,
        length: 30,
        weight: 12.5,
        photos: [
          BoxPhoto(
            id: 'bp-101',
            url: 'https://picsum.photos/seed/box101/600/400',
            comment: 'Взвешивание коробки №1',
          ),
        ],
      ),
      Box(
        id: 102,
        number: 2,
        height: 35,
        width: 35,
        length: 25,
        weight: 7.8,
        photos: [
          BoxPhoto(
            id: 'bp-102',
            url: 'https://picsum.photos/seed/box102/600/400',
            comment: 'Взвешивание коробки №2',
          ),
        ],
      ),
    ],
    scalePhotos: [
      ScalePhoto(
        id: 'sp-201',
        url: 'https://picsum.photos/seed/scale201/600/400',
      ),
    ],
  );

  // ── Треки ────────────────────────────────────────────────────────────────

  static final List<TrackItem> tracks = [
    // Трек 1001 — с фотоотчётом (запрос выполнен)
    TrackItem(
      id: 1001,
      code: 'CN2025031400001',
      status: 'На складе в Китае',
      statusCode: 'in_warehouse_cn',
      statusColor: '0F766E',
      date: DateTime(_now.year, _now.month, _now.day - 1),
      createdAt: DateTime(_now.year, _now.month, _now.day - 3),
      updatedAt: DateTime(_now.year, _now.month, _now.day - 1),
      photoRequests: [
        PhotoRequest(
          id: 301,
          wishes: 'Пожалуйста, сфотографируйте товар со всех сторон',
          warehouseComment: 'Товар сфотографирован, все стороны видны',
          status: 'completed',
          mediaUrls: [
            'https://picsum.photos/seed/photo301a/600/400',
            'https://picsum.photos/seed/photo301b/600/400',
            'https://picsum.photos/seed/photo301c/600/400',
          ],
          createdAt: DateTime(_now.year, _now.month, _now.day - 2),
          completedAt: DateTime(_now.year, _now.month, _now.day - 1),
          completedByName: 'Склад 2A',
        ),
      ],
    ),

    // Трек 1002 — входит в сборку (часть 1)
    TrackItem(
      id: 1002,
      code: 'CN2025031300042',
      status: 'Отправлен в Россию',
      statusCode: 'shipped_to_ru',
      statusColor: '2563EB',
      date: DateTime(_now.year, _now.month, _now.day - 2),
      createdAt: DateTime(_now.year, _now.month, _now.day - 5),
      updatedAt: DateTime(_now.year, _now.month, _now.day - 2),
      groupId: '501',
      assembly: _demoAssembly,
    ),

    // Трек 1003 — входит в сборку (часть 2) + информация о товаре
    TrackItem(
      id: 1003,
      code: 'CN2025031200018',
      status: 'Отправлен в Россию',
      statusCode: 'shipped_to_ru',
      statusColor: '2563EB',
      date: DateTime(_now.year, _now.month, _now.day - 2),
      createdAt: DateTime(_now.year, _now.month, _now.day - 6),
      updatedAt: DateTime(_now.year, _now.month, _now.day - 2),
      groupId: '501',
      assembly: _demoAssembly,
      productInfo: const ProductInfo(
        id: 401,
        name: 'Кроссовки Nike Air Max 270',
        quantity: 2,
      ),
    ),

    // Трек 1004 — фото на весах (photoReportUrls)
    TrackItem(
      id: 1004,
      code: 'CN2025031100007',
      status: 'На складе в России',
      statusCode: 'in_warehouse_ru',
      statusColor: '7C3AED',
      date: DateTime(_now.year, _now.month, _now.day - 1),
      createdAt: DateTime(_now.year, _now.month, _now.day - 4),
      updatedAt: DateTime(_now.year, _now.month, _now.day - 1),
      photoReportUrls: [
        'https://picsum.photos/seed/report401/600/400',
        'https://picsum.photos/seed/report402/600/400',
      ],
    ),

    // Трек 1005 — вопрос о товаре (отвечен)
    TrackItem(
      id: 1005,
      code: 'CN2025031000033',
      status: 'На складе в Китае',
      statusCode: 'in_warehouse_cn',
      statusColor: '0F766E',
      date: DateTime(_now.year, _now.month, _now.day - 3),
      createdAt: DateTime(_now.year, _now.month, _now.day - 7),
      updatedAt: DateTime(_now.year, _now.month, _now.day - 3),
      questions: [
        TrackQuestion(
          id: 501,
          question: 'Когда посылка прибудет на склад в Китае?',
          answer: 'Ожидаем поступление товара на склад в течение 3–5 рабочих дней.',
          status: 'completed',
          createdAt: DateTime(_now.year, _now.month, _now.day - 4),
          answeredAt: DateTime(_now.year, _now.month, _now.day - 3),
          answeredByName: 'Менеджер 2A',
        ),
      ],
    ),

    TrackItem(
      id: 1006,
      code: 'CN2025030900011',
      status: 'Отправлен в Россию',
      statusCode: 'shipped_to_ru',
      statusColor: '2563EB',
      date: DateTime(_now.year, _now.month, _now.day - 5),
      createdAt: DateTime(_now.year, _now.month, _now.day - 8),
      updatedAt: DateTime(_now.year, _now.month, _now.day - 5),
    ),
    TrackItem(
      id: 1007,
      code: 'CN2025030800055',
      status: 'Получен клиентом',
      statusCode: 'delivered',
      statusColor: '1B8A5A',
      date: DateTime(_now.year, _now.month, _now.day - 7),
      createdAt: DateTime(_now.year, _now.month, _now.day - 14),
      updatedAt: DateTime(_now.year, _now.month, _now.day - 7),
    ),
    TrackItem(
      id: 1008,
      code: 'CN2025030700022',
      status: 'В ожидании',
      statusCode: 'waiting',
      statusColor: 'B45309',
      date: DateTime(_now.year, _now.month, _now.day),
      createdAt: DateTime(_now.year, _now.month, _now.day),
      updatedAt: DateTime(_now.year, _now.month, _now.day),
    ),
  ];

  static int get tracksCount => tracks.length;
  static int get assembliesCount => 2;
  static int get invoicesCount => invoices.length;
  static int get photosCount => photos.length;

  // ── Фотоотчёты ───────────────────────────────────────────────────────────

  static final List<PhotoItem> photos = [
    PhotoItem(
      id: 601,
      url: 'https://picsum.photos/seed/photo601/600/400',
      date: DateTime(_now.year, _now.month, _now.day - 1),
      trackingNumber: 'CN2025031400001',
    ),
    PhotoItem(
      id: 602,
      url: 'https://picsum.photos/seed/photo602/600/400',
      date: DateTime(_now.year, _now.month, _now.day - 1),
      trackingNumber: 'CN2025031400001',
    ),
    PhotoItem(
      id: 603,
      url: 'https://picsum.photos/seed/photo603/600/400',
      date: DateTime(_now.year, _now.month, _now.day - 2),
      trackingNumber: 'CN2025031300042',
    ),
    PhotoItem(
      id: 604,
      url: 'https://picsum.photos/seed/photo604/600/400',
      date: DateTime(_now.year, _now.month, _now.day - 2),
      trackingNumber: 'CN2025031300042',
    ),
    PhotoItem(
      id: 605,
      url: 'https://picsum.photos/seed/photo605/600/400',
      date: DateTime(_now.year, _now.month, _now.day - 4),
      trackingNumber: 'CN2025031100007',
    ),
  ];

  // ── Счета ────────────────────────────────────────────────────────────────

  // ── СП Сборки ─────────────────────────────────────────────────────────────

  static final List<SpAssembly> spAssemblies = [
    SpAssembly(
      id: 501,
      assemblyNumber: 'A-2025-0501',
      name: 'Демо сборка СП',
      status: 'shipped',
      totalShippingCostRub: 3700,
      defaultPurchaseRate: 12.5,
      createdAt: DateTime(_now.year, _now.month, _now.day - 10),
      updatedAt: DateTime(_now.year, _now.month, _now.day - 2),
      tracks: [
        const SpTrack(
          id: 1002,
          trackNumber: 'CN2025031300042',
          spParticipantName: 'Иван',
          clientPriceYuan: 350,
          purchaseRate: 12.5,
          netWeightKg: 5.2,
          clientPriceRub: 4375,
          shippingCostRub: 936,
          totalCostRub: 5311,
          status: 'shipped_to_ru',
        ),
        const SpTrack(
          id: 1003,
          trackNumber: 'CN2025031200018',
          spParticipantName: 'Мария',
          clientPriceYuan: 480,
          purchaseRate: 12.5,
          netWeightKg: 7.3,
          clientPriceRub: 6000,
          shippingCostRub: 1314,
          totalCostRub: 7314,
          status: 'shipped_to_ru',
          productTitle: 'Кроссовки Nike Air Max 270',
        ),
      ],
      invoices: [],
      stats: const SpStats(
        tracksTotal: 2,
        tracksWithSP: 2,
        grossWeightKg: 12.5,
        totalNetWeightKg: 12.5,
        totalCostRub: 12625,
        totalRevenueRub: 12625,
        totalShippingRub: 2250,
        totalProfitRub: 0,
        participants: [
          SpParticipant(name: 'Иван', trackCount: 1, weight: 5.2, totalAmount: 5311),
          SpParticipant(name: 'Мария', trackCount: 1, weight: 7.3, totalAmount: 7314),
        ],
      ),
    ),
  ];

  // ── Счета ────────────────────────────────────────────────────────────────

  static final List<InvoiceItem> invoices = [
    InvoiceItem(
      id: 'demo-inv-001',
      invoiceNumber: 'INV-2025-0142',
      sendDate: DateTime(_now.year, _now.month, _now.day - 5),
      arrivalDate: DateTime(_now.year, _now.month, _now.day + 10),
      status: 'pending',
      statusName: 'Требует оплаты',
      statusColor: 'B45309',
      tariffName: 'Стандарт',
      placesCount: 3,
      density: 150,
      weight: 12.5,
      volume: 0.083,
      totalCostUsd: 87.5,
      clientRubRate: 92.0,
      totalCostRub: 8050,
    ),
    InvoiceItem(
      id: 'demo-inv-002',
      invoiceNumber: 'INV-2025-0128',
      sendDate: DateTime(_now.year, _now.month, _now.day - 18),
      arrivalDate: DateTime(_now.year, _now.month, _now.day - 5),
      paidAt: DateTime(_now.year, _now.month, _now.day - 4),
      status: 'paid',
      statusName: 'Оплачен',
      statusColor: '1B8A5A',
      tariffName: 'Стандарт',
      placesCount: 5,
      density: 150,
      weight: 24.0,
      volume: 0.16,
      totalCostUsd: 168.0,
      clientRubRate: 90.5,
      totalCostRub: 15204,
    ),
    InvoiceItem(
      id: 'demo-inv-003',
      invoiceNumber: 'INV-2025-0109',
      sendDate: DateTime(_now.year, _now.month - 1, 20),
      arrivalDate: DateTime(_now.year, _now.month, 5),
      paidAt: DateTime(_now.year, _now.month, 6),
      status: 'paid',
      statusName: 'Оплачен',
      statusColor: '1B8A5A',
      tariffName: 'Эконом',
      placesCount: 2,
      density: 120,
      weight: 8.0,
      volume: 0.067,
      totalCostUsd: 40.0,
      clientRubRate: 89.0,
      totalCostRub: 3560,
    ),
  ];

  // ── Демо-правила ──────────────────────────────────────────────────────────
  static const List<RuleItem> rules = [
    RuleItem(
      slug: 'demo-rule-1',
      title: 'Ограничения по весу и габаритам',
      excerpt: 'Максимальный вес одного места — 30 кг. Превышение согласовывается дополнительно.',
      content: 'Максимальный вес одного места — 30 кг. Превышение согласовывается дополнительно.',
      order: 1,
    ),
    RuleItem(
      slug: 'demo-rule-2',
      title: 'Запрещённые к отправке товары',
      excerpt: 'Запрещено: аккумуляторы отдельно от техники, жидкости, легковоспламеняющиеся материалы.',
      content: 'Запрещено: аккумуляторы отдельно от техники, жидкости, легковоспламеняющиеся материалы.',
      order: 2,
    ),
    RuleItem(
      slug: 'demo-rule-3',
      title: 'Сроки бесплатного хранения',
      excerpt: 'Бесплатное хранение на складе — 30 дней. После истечения срока начисляется плата за хранение.',
      content: 'Бесплатное хранение на складе — 30 дней. После истечения срока начисляется плата за хранение.',
      order: 3,
    ),
    RuleItem(
      slug: 'demo-rule-4',
      title: 'Порядок оплаты и выдачи',
      excerpt: 'Груз выдаётся только после полной оплаты счёта. Оплата принимается переводом или USDT.',
      content: 'Груз выдаётся только после полной оплаты счёта. Оплата принимается переводом или USDT.',
      order: 4,
    ),
  ];
}
