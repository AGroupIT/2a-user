import 'package:flutter/foundation.dart';

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
  final List<String> photoReportUrls;
  final ProductInfo? productInfo;
  final List<PhotoRequest> photoRequests;
  final List<TrackQuestion> questions;
  final String? clientCode;

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
    this.photoReportUrls = const [],
    this.productInfo,
    this.photoRequests = const [],
    this.questions = const [],
    this.clientCode,
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

  factory TrackItem.fromJson(Map<String, dynamic> json) {
    // Получаем код трека
    final code = json['code'] as String? ?? 
                 json['trackNumber'] as String? ?? 
                 'TRK-${json['id']}';
    
    // Получаем статус - сначала statusName из API, потом fallback
    final status = json['statusName'] as String? ?? json['status'] as String? ?? 'unknown';
    final statusCode = json['status'] as String? ?? '';
    final statusColor = json['statusColor'] as String?;
    
    // Получаем дату обновления (для сортировки по изменениям) или дату создания
    DateTime date;
    if (json['updatedAt'] != null) {
      date = DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      date = DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }
    
    final createdAt = json['createdAt'] != null 
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    final updatedAt = json['updatedAt'] != null 
        ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    
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
      // DEBUG: Логируем данные сборки от API
      if (assemblyJson['deliveryMethod'] != null) {
        debugPrint('[DEBUG] Assembly ${assemblyJson['id']} from API: deliveryMethod=${assemblyJson['deliveryMethod']}, recipientCity=${assemblyJson['recipientCity']}');
      } else {
        debugPrint('[DEBUG] Assembly ${assemblyJson['id']} from API: NO deliveryMethod! Keys: ${assemblyJson.keys.toList()}');
      }
      assembly = TrackAssembly.fromJson(assemblyJson);
    }
    
    // Парсим информацию о товаре (productInfo - массив, берем первый)
    ProductInfo? productInfo;
    final productInfoList = json['productInfo'] as List<dynamic>?;
    if (productInfoList != null && productInfoList.isNotEmpty) {
      productInfo = ProductInfo.fromJson(productInfoList.first as Map<String, dynamic>);
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
    
    // Код клиента
    final clientCodeData = json['clientCode'] as Map<String, dynamic>?;
    final clientCode = clientCodeData?['code'] as String?;
    
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
      photoReportUrls: photoUrls,
      productInfo: productInfo,
      photoRequests: photoRequests,
      questions: questions,
      clientCode: clientCode,
    );
  }
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
  
  // Тариф
  final String? tariffName;
  final double? tariffCost;
  
  // Упаковка
  final List<String> packagingTypes;
  final double? packagingCost;
  
  // Страховка
  final bool hasInsurance;
  final double? insuranceAmount;

  // Способ получения
  final String? deliveryMethod; // 'self_pickup' или 'transport_company'
  final String? recipientName;
  final String? recipientPhone;
  final String? recipientCity;
  final String? transportCompanyName; // Название транспортной компании

  const TrackAssembly({
    required this.id,
    required this.number,
    this.name,
    required this.status,
    this.statusName,
    this.statusColor,
    this.comment,
    this.tariffName,
    this.tariffCost,
    this.packagingTypes = const [],
    this.packagingCost,
    this.hasInsurance = false,
    this.insuranceAmount,
    this.deliveryMethod,
    this.recipientName,
    this.recipientPhone,
    this.recipientCity,
    this.transportCompanyName,
  });

  factory TrackAssembly.fromJson(Map<String, dynamic> json) {
    // Парсим типы упаковки (API может возвращать packagingTypes или packagingNames)
    List<String> packagingTypes = [];
    if (json['packagingTypes'] != null && json['packagingTypes'] is List) {
      packagingTypes = (json['packagingTypes'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['packagingNames'] != null && json['packagingNames'] is List) {
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
    
    return TrackAssembly(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      number: json['number']?.toString() ?? '',
      name: json['name']?.toString(),
      status: json['status']?.toString() ?? '',
      statusName: json['statusName']?.toString(),
      statusColor: json['statusColor']?.toString(),
      comment: json['comment']?.toString(),
      tariffName: json['tariffName']?.toString(),
      tariffCost: parseDouble(json['tariffCost']),
      packagingTypes: packagingTypes,
      packagingCost: parseDouble(json['packagingCost']),
      hasInsurance: json['hasInsurance'] == true || json['hasInsurance'] == 'true',
      insuranceAmount: parseDouble(json['insuranceAmount']),
      deliveryMethod: json['deliveryMethod']?.toString(),
      recipientName: json['recipientName']?.toString(),
      recipientPhone: json['recipientPhone']?.toString(),
      recipientCity: json['recipientCity']?.toString(),
      transportCompanyName: json['transportCompanyName']?.toString(),
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
  final String status; // new, in_progress, assigned, completed, cancelled
  final List<String> mediaUrls;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? completedByName;

  const PhotoRequest({
    required this.id,
    this.wishes,
    required this.status,
    this.mediaUrls = const [],
    required this.createdAt,
    this.completedAt,
    this.completedByName,
  });

  String get statusLabel {
    switch (status) {
      case 'new':
        return 'Новый';
      case 'in_progress':
        return 'В работе';
      case 'assigned':
        return 'Назначен';
      case 'completed':
        return 'Выполнен';
      case 'cancelled':
        return 'Отменен';
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
      status: json['status'] as String? ?? 'new',
      mediaUrls: mediaUrls,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completedAt'] != null 
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      completedByName: (json['completedBy'] as Map<String, dynamic>?)?['fullName'] as String?,
    );
  }
}

// Вопрос по треку
class TrackQuestion {
  final int id;
  final String question;
  final String? answer;
  final String status; // new, in_progress, completed, cancelled
  final DateTime createdAt;
  final DateTime? answeredAt;
  final String? answeredByName;

  const TrackQuestion({
    required this.id,
    required this.question,
    this.answer,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.answeredByName,
  });

  String get statusLabel {
    switch (status) {
      case 'new':
        return 'Новый';
      case 'in_progress':
        return 'В работе';
      case 'completed':
        return 'Отвечен';
      case 'cancelled':
        return 'Отменен';
      default:
        return status;
    }
  }

  bool get isActive => status != 'cancelled' && status != 'completed';
  bool get hasAnswer => answer != null && answer!.isNotEmpty;

  factory TrackQuestion.fromJson(Map<String, dynamic> json) {
    return TrackQuestion(
      id: json['id'] as int,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String?,
      status: json['status'] as String? ?? 'new',
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      answeredAt: json['answeredAt'] != null 
          ? DateTime.tryParse(json['answeredAt'].toString())
          : null,
      answeredByName: (json['answeredBy'] as Map<String, dynamic>?)?['fullName'] as String?,
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
