import '../../assemblies/domain/box.dart';
import '../../sp_finance/data/sp_models.dart';
import '../../../core/models/status_timeline_entry.dart';

class TrackItem {
  final int? id;
  final String code;
  final String status;
  final String statusCode; // Код статуса для фильтрации
  final String? statusColor;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? groupId;
  final TrackAssembly? assembly;
  final String? comment;
  final String? invoiceNumber;
  final List<String> photoReportUrls;
  final ProductInfo? productInfo;
  final List<PhotoRequest> photoRequests;
  final List<TrackQuestion> questions;
  final String? clientCode;
  final int? clientCodeId;
  final List<StatusTimelineEntry> statusHistory;
  final List<TrackSpItem> spItems;
  final bool? canAddToAssembly;
  final String? assemblyBlockReason;

  const TrackItem({
    this.id,
    required this.code,
    required this.status,
    this.statusCode = '',
    this.statusColor,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.groupId,
    this.assembly,
    this.comment,
    this.invoiceNumber,
    this.photoReportUrls = const [],
    this.productInfo,
    this.photoRequests = const [],
    this.questions = const [],
    this.clientCode,
    this.clientCodeId,
    this.statusHistory = const [],
    this.spItems = const [],
    this.canAddToAssembly,
    this.assemblyBlockReason,
  });

  // Последний активный фотозапрос (не отмененный)
  PhotoRequest? get activePhotoRequest {
    final active = photoRequests.where((r) => r.status != 'cancelled').toList();
    return active.isNotEmpty ? active.first : null;
  }

  // Последний активный вопрос (не отмененный)
  TrackQuestion? get activeQuestion {
    final active = questions.where((q) => q.status != 'cancelled').toList();
    return active.isNotEmpty ? active.first : null;
  }

  // Есть ли активный запрос фотоотчета
  bool get hasActivePhotoRequest => activePhotoRequest != null;

  // Есть ли активный вопрос
  bool get hasActiveQuestion => activeQuestion != null;

  /// Удаление разрешено только для треков, которые ещё не приняты складом.
  ///
  /// Основной источник истины — серверный код статуса. Текстовый fallback
  /// оставлен для старых ответов API, где `statusCode` ещё не передавался.
  bool get isPending =>
      statusCode == 'pending' || (statusCode.isEmpty && status == 'В ожидании');

  /// Серверный признак имеет приоритет. Fallback сохраняет совместимость со
  /// старым backend, который ещё не возвращает причины блокировки.
  bool get isAvailableForAssemblySelection =>
      canAddToAssembly ??
      ((statusCode == 'in_warehouse' || status == 'На складе') &&
          assembly == null);

  String? get assemblySelectionHint => switch (assemblyBlockReason) {
    'warehouse_arrival_cooldown' =>
      'Трек только поступил на склад. Добавить в сборку можно завтра.',
    'return_requested' => 'По треку запрошен возврат',
    _ => null,
  };

  factory TrackItem.fromJson(Map<String, dynamic> json) {
    // Получаем код трека
    final code =
        json['code'] as String? ??
        json['trackNumber'] as String? ??
        'TRK-${json['id']}';

    // Получаем статус - сначала statusName из API, потом fallback
    final status =
        json['statusName'] as String? ?? json['status'] as String? ?? 'unknown';
    final statusCode = json['status'] as String? ?? '';
    final statusColor = json['statusColor'] as String?;

    final createdAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    final updatedAt = json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    final date = createdAt;

    // Получаем фото из photos
    final photos = json['photos'] as List<dynamic>? ?? [];
    final photoUrls = photos
        .map((p) => (p as Map<String, dynamic>)['url'] as String?)
        .whereType<String>()
        .toList();

    // Парсим сборку
    TrackAssembly? assembly;
    if (json['assembly'] != null) {
      final assemblyJson = json['assembly'] as Map<String, dynamic>;
      assembly = TrackAssembly.fromJson(assemblyJson);
    }

    // Парсим информацию о товаре (productInfo - массив, берем первый)
    ProductInfo? productInfo;
    final productInfoList = json['productInfo'] as List<dynamic>?;
    if (productInfoList != null && productInfoList.isNotEmpty) {
      productInfo = ProductInfo.fromJson(
        productInfoList.first as Map<String, dynamic>,
      );
    }

    // Парсим фото-запросы
    final photoRequestsList = json['photoRequests'] as List<dynamic>? ?? [];
    final photoRequests = photoRequestsList
        .map((pr) => PhotoRequest.fromJson(pr as Map<String, dynamic>))
        .toList();

    // Парсим вопросы
    final questionsList = json['questions'] as List<dynamic>? ?? [];
    final questions = questionsList
        .map((q) => TrackQuestion.fromJson(q as Map<String, dynamic>))
        .toList();

    final statusHistoryList = json['statusHistory'] as List<dynamic>? ?? [];
    final statusHistory = statusHistoryList
        .whereType<Map<String, dynamic>>()
        .map(StatusTimelineEntry.fromStatusHistoryJson)
        .toList();

    final spItemsList = json['spItems'] as List<dynamic>? ?? [];
    final spItems = spItemsList
        .whereType<Map<String, dynamic>>()
        .map(TrackSpItem.fromJson)
        .toList();

    // Код клиента
    final clientCodeData = json['clientCode'] as Map<String, dynamic>?;
    final clientCode = clientCodeData?['code'] as String?;
    final clientCodeId = clientCodeData?['id'] as int?;

    return TrackItem(
      id: json['id'] as int?,
      code: code,
      status: status,
      statusCode: statusCode,
      statusColor: statusColor,
      date: date,
      createdAt: createdAt,
      updatedAt: updatedAt,
      groupId: json['assemblyId']?.toString(),
      assembly: assembly,
      comment: json['note'] as String?, // note - это комментарий клиента
      invoiceNumber:
          json['invoiceNumber']?.toString() ?? assembly?.invoiceNumber,
      photoReportUrls: photoUrls,
      productInfo: productInfo,
      photoRequests: photoRequests,
      questions: questions,
      clientCode: clientCode,
      clientCodeId: clientCodeId,
      statusHistory: statusHistory,
      spItems: spItems,
      canAddToAssembly: json['canAddToAssembly'] as bool?,
      assemblyBlockReason: json['assemblyBlockReason']?.toString(),
    );
  }
}

class TrackSpItem {
  final int id;
  final String title;
  final String status;
  final String? sourceUrl;
  final int quantity;
  final int? linkQuantity;
  final String? linkComment;
  final double? clientPriceYuan;
  final double? clientPriceRub;
  final double? shippingCostRub;
  final double? additionalExpensesRub;
  final TrackSpCustomer? customer;
  final TrackSpPurchase? purchase;
  final List<TrackSpMedia> media;

  const TrackSpItem({
    required this.id,
    required this.title,
    required this.status,
    this.sourceUrl,
    required this.quantity,
    this.linkQuantity,
    this.linkComment,
    this.clientPriceYuan,
    this.clientPriceRub,
    this.shippingCostRub,
    this.additionalExpensesRub,
    this.customer,
    this.purchase,
    this.media = const [],
  });

  factory TrackSpItem.fromJson(Map<String, dynamic> json) {
    return TrackSpItem(
      id: _readInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Товар СП',
      status: json['status']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString(),
      quantity: _readInt(json['quantity']) ?? 1,
      linkQuantity: _readInt(json['linkQuantity']),
      linkComment: json['linkComment']?.toString(),
      clientPriceYuan: _readDouble(json['clientPriceYuan']),
      clientPriceRub: _readDouble(json['clientPriceRub']),
      shippingCostRub: _readDouble(json['shippingCostRub']),
      additionalExpensesRub: _readDouble(json['additionalExpensesRub']),
      customer: json['customer'] is Map<String, dynamic>
          ? TrackSpCustomer.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      purchase: json['purchase'] is Map<String, dynamic>
          ? TrackSpPurchase.fromJson(json['purchase'] as Map<String, dynamic>)
          : null,
      media:
          (json['media'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(TrackSpMedia.fromJson)
              .toList() ??
          const [],
    );
  }
}

class TrackSpCustomer {
  final int id;
  final String fullName;
  final String? phone;
  final String? telegram;

  const TrackSpCustomer({
    required this.id,
    required this.fullName,
    this.phone,
    this.telegram,
  });

  factory TrackSpCustomer.fromJson(Map<String, dynamic> json) {
    return TrackSpCustomer(
      id: _readInt(json['id']) ?? 0,
      fullName: json['fullName']?.toString() ?? 'Клиент СП',
      phone: json['phone']?.toString(),
      telegram: json['telegram']?.toString(),
    );
  }
}

class TrackSpPurchase {
  final int id;
  final String title;
  final String currency;

  const TrackSpPurchase({
    required this.id,
    required this.title,
    required this.currency,
  });

  factory TrackSpPurchase.fromJson(Map<String, dynamic> json) {
    return TrackSpPurchase(
      id: _readInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Совместная покупка',
      currency: json['currency']?.toString() ?? 'CNY',
    );
  }
}

class TrackSpMedia {
  final int id;
  final String url;
  final String? thumbnailUrl;

  const TrackSpMedia({required this.id, required this.url, this.thumbnailUrl});

  factory TrackSpMedia.fromJson(Map<String, dynamic> json) {
    return TrackSpMedia(
      id: _readInt(json['id']) ?? 0,
      url: json['url']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
    );
  }
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _readDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

// Сборка (Assembly)
class TrackAssembly {
  final int id;
  final String number;
  final String? name;
  final String status;
  final String? statusName;
  final String? statusColor;
  final String? comment;
  final String? invoiceNumber;

  // Тариф
  final String? tariffName;
  final double? tariffCost;

  // Упаковка
  final List<String> packagingTypes;
  final double? packagingCost;
  final bool hasFragileGoods;
  final String placePreference;

  // Страховка
  final bool hasInsurance;
  final double? insuranceAmount;

  // Способ получения
  final String? goodsDescription; // Общее описание товаров в сборке

  final String? deliveryMethod; // 'self_pickup' или 'transport_company'
  final String? recipientName;
  final String? recipientPhone;
  final String? recipientCity;
  final String? transportCompanyName; // Название транспортной компании

  // Коробки (новое)
  final List<Box> boxes;

  // Фото на весах (старые, для обратной совместимости)
  final List<ScalePhoto> scalePhotos;
  final List<StatusTimelineEntry> statusHistory;

  // Количество треков в сборке (с бэка через _count, не зависит от
  // пагинации клиента). Null если бэк не вернул поле.
  final int? trackCount;

  const TrackAssembly({
    required this.id,
    required this.number,
    this.name,
    required this.status,
    this.statusName,
    this.statusColor,
    this.comment,
    this.invoiceNumber,
    this.tariffName,
    this.tariffCost,
    this.packagingTypes = const [],
    this.packagingCost,
    this.hasFragileGoods = false,
    this.placePreference = 'unspecified',
    this.hasInsurance = false,
    this.insuranceAmount,
    this.goodsDescription,
    this.deliveryMethod,
    this.recipientName,
    this.recipientPhone,
    this.recipientCity,
    this.transportCompanyName,
    this.boxes = const [],
    this.scalePhotos = const [],
    this.statusHistory = const [],
    this.trackCount,
  });

  factory TrackAssembly.fromJson(Map<String, dynamic> json) {
    // Парсим типы упаковки (API может возвращать packagingTypes или packagingNames)
    List<String> packagingTypes = [];
    if (json['packagingTypes'] != null && json['packagingTypes'] is List) {
      packagingTypes = (json['packagingTypes'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['packagingNames'] != null &&
        json['packagingNames'] is List) {
      // Fallback для старого формата API
      packagingTypes = (json['packagingNames'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['packagingTypeName'] != null) {
      packagingTypes = [json['packagingTypeName'].toString()];
    }

    // Безопасный парсинг чисел (могут быть строками)
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final scalePhotosList =
        (json['scalePhotos'] as List<dynamic>?)
            ?.map((e) => ScalePhoto.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Парсим коробки
    final boxesList =
        (json['boxes'] as List<dynamic>?)
            ?.map((e) => Box.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final eventsList = json['events'] as List<dynamic>? ?? [];
    final statusHistory = eventsList
        .whereType<Map<String, dynamic>>()
        .where((event) => event['eventType']?.toString() == 'status_changed')
        .map(StatusTimelineEntry.fromEventJson)
        .toList();

    return TrackAssembly(
      id: json['id'] is int
          ? json['id'] as int
          : int.parse(json['id'].toString()),
      number: json['number']?.toString() ?? '',
      name: json['name']?.toString(),
      status: json['status']?.toString() ?? '',
      statusName: json['statusName']?.toString(),
      statusColor: json['statusColor']?.toString(),
      comment: json['comment']?.toString(),
      invoiceNumber: json['invoiceNumber']?.toString(),
      tariffName: json['tariffName']?.toString(),
      tariffCost: parseDouble(json['tariffCost']),
      packagingTypes: packagingTypes,
      packagingCost: parseDouble(json['packagingCost']),
      hasFragileGoods:
          json['hasFragileGoods'] == true || json['hasFragileGoods'] == 'true',
      placePreference: json['placePreference']?.toString() ?? 'unspecified',
      hasInsurance:
          json['hasInsurance'] == true || json['hasInsurance'] == 'true',
      insuranceAmount: parseDouble(json['insuranceAmount']),
      goodsDescription: json['goodsDescription']?.toString(),
      deliveryMethod: json['deliveryMethod']?.toString(),
      recipientName: json['recipientName']?.toString(),
      recipientPhone: json['recipientPhone']?.toString(),
      recipientCity: json['recipientCity']?.toString(),
      transportCompanyName: json['transportCompanyName']?.toString(),
      boxes: boxesList,
      scalePhotos: scalePhotosList,
      statusHistory: statusHistory,
      trackCount: json['trackCount'] is int
          ? json['trackCount'] as int
          : int.tryParse(json['trackCount']?.toString() ?? ''),
    );
  }
}

// Информация о товаре
class ProductInfo {
  final int? id;
  final String? name;
  final int quantity;
  final String? imageUrl;
  final DateTime? createdAt;

  const ProductInfo({
    this.id,
    this.name,
    this.quantity = 1,
    this.imageUrl,
    this.createdAt,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      id: json['id'] as int?,
      name: json['name'] as String? ?? json['productName'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

// Запрос фотоотчета
class PhotoRequest {
  final int id;
  final String? wishes;
  final String? warehouseComment;
  final String status; // new, in_progress, assigned, completed, cancelled
  final List<String> mediaUrls;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? completedByName;

  const PhotoRequest({
    required this.id,
    this.wishes,
    this.warehouseComment,
    required this.status,
    this.mediaUrls = const [],
    required this.createdAt,
    this.completedAt,
    this.completedByName,
  });

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Ожидает выполнения';
      case 'new':
        return 'Новый';
      case 'at_warehouse':
        return 'На складе';
      case 'in_progress':
        return 'Передан в работу';
      case 'assigned':
        return 'Назначен ответственный';
      case 'completed':
        return 'Выполнен';
      case 'cancelled':
        return 'Отменён';
      default:
        return status;
    }
  }

  bool get isActive => status != 'cancelled' && status != 'completed';

  factory PhotoRequest.fromJson(Map<String, dynamic> json) {
    // Парсим фотографии из photos
    final photos = json['photos'] as List<dynamic>? ?? [];
    final mediaUrls = photos
        .map((p) => (p as Map<String, dynamic>)['url'] as String?)
        .whereType<String>()
        .toList();

    return PhotoRequest(
      id: json['id'] as int,
      wishes: json['wish'] as String?,
      warehouseComment: json['warehouseComment'] as String?,
      status: json['status'] as String? ?? 'new',
      mediaUrls: mediaUrls,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      completedByName:
          (json['completedBy'] as Map<String, dynamic>?)?['fullName']
              as String?,
    );
  }
}

// Вопрос по треку
class TrackQuestion {
  final int id;
  final String question;
  final String? answer;
  final String status; // new, in_progress, completed, cancelled
  final String? questionType;
  final List<String> answerPhotoUrls;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final String? answeredByName;

  const TrackQuestion({
    required this.id,
    required this.question,
    this.answer,
    required this.status,
    this.questionType,
    this.answerPhotoUrls = const [],
    required this.createdAt,
    this.answeredAt,
    this.answeredByName,
  });

  String get statusLabel {
    switch (status) {
      case 'new':
        return 'Новый';
      case 'at_warehouse':
        return 'На складе';
      case 'in_progress':
        return 'Передан в работу';
      case 'assigned':
        return 'Назначен ответственный';
      case 'answered':
      case 'completed':
        return 'Отвечен';
      case 'closed':
        return 'Закрыт';
      case 'cancelled':
        return 'Отменён';
      default:
        return status;
    }
  }

  bool get isActive =>
      status != 'cancelled' &&
      status != 'completed' &&
      status != 'answered' &&
      status != 'closed';
  bool get hasAnswer => answer != null && answer!.isNotEmpty;
  bool get hasResponse =>
      hasAnswer ||
      answerPhotoUrls.isNotEmpty ||
      status == 'completed' ||
      status == 'answered';

  factory TrackQuestion.fromJson(Map<String, dynamic> json) {
    return TrackQuestion(
      id: json['id'] as int,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String?,
      status: json['status'] as String? ?? 'new',
      questionType: json['questionType'] as String?,
      answerPhotoUrls:
          (json['answerPhotoUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      answeredAt: json['answeredAt'] != null
          ? DateTime.tryParse(json['answeredAt'].toString())
          : null,
      answeredByName:
          (json['answeredBy'] as Map<String, dynamic>?)?['fullName'] as String?,
    );
  }
}

class TrackReturnInfo {
  final int id;
  final String returnCode;
  final String status;
  final String? screenshotUrl;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TrackReturnInfo({
    required this.id,
    required this.returnCode,
    required this.status,
    this.screenshotUrl,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  String get statusLabel {
    return switch (status) {
      'pending' => 'Ожидает обработки',
      'in_progress' => 'В работе',
      'completed' => 'Выполнен',
      'cancelled' => 'Отменён',
      _ => status,
    };
  }

  factory TrackReturnInfo.fromJson(Map<String, dynamic> json) {
    return TrackReturnInfo(
      id: _readInt(json['id']) ?? 0,
      returnCode: json['returnCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      screenshotUrl: json['screenshotUrl']?.toString(),
      note: json['note']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

enum PhotoTaskStatus {
  newTask,
  done,
  cancelled;

  String get label {
    switch (this) {
      case PhotoTaskStatus.newTask:
        return 'NEW';
      case PhotoTaskStatus.done:
        return 'DONE';
      case PhotoTaskStatus.cancelled:
        return 'CANCELLED';
    }
  }
}
