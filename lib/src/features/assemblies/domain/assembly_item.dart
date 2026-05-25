import 'box.dart';
import '../../../core/models/status_timeline_entry.dart';

/// Модель сборки для клиентского приложения
class AssemblyItem {
  final int id;
  final String number;
  final String status;
  final String statusCode;
  final String? statusColor;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int tracksCount;
  final String? tariffName;
  final String? packagingName;
  final bool hasFragileGoods;
  final String placePreference;
  final List<Box> boxes;
  final List<StatusTimelineEntry> statusHistory;

  const AssemblyItem({
    required this.id,
    required this.number,
    required this.status,
    this.statusCode = '',
    this.statusColor,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.tracksCount = 0,
    this.tariffName,
    this.packagingName,
    this.hasFragileGoods = false,
    this.placePreference = 'unspecified',
    this.boxes = const [],
    this.statusHistory = const [],
  });

  factory AssemblyItem.fromJson(Map<String, dynamic> json) {
    // Получаем статус
    final statusData = json['statusData'] as Map<String, dynamic>?;
    final statusCode = json['status']?.toString() ?? '';
    final status =
        statusData?['nameRu'] as String? ??
        json['statusName'] as String? ??
        json['statusNameRu'] as String? ??
        statusCode.ifEmpty('unknown');
    final statusColor =
        statusData?['color'] as String? ?? json['statusColor'] as String?;

    // Получаем дату
    final createdAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    final updatedAt = json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'].toString()) ?? createdAt
        : createdAt;

    // Количество треков
    final tracks = json['tracks'] as List<dynamic>?;
    final tracksCount = tracks?.length ?? json['tracksCount'] as int? ?? 0;

    // Тариф и упаковка
    final tariff = json['tariff'] as Map<String, dynamic>?;
    final packaging = json['packagingType'] as Map<String, dynamic>?;

    // Коробки
    final boxesData = json['boxes'] as List<dynamic>?;
    final boxes =
        boxesData
            ?.map((b) => Box.fromJson(b as Map<String, dynamic>))
            .toList() ??
        [];

    final eventsList = json['events'] as List<dynamic>? ?? [];
    final statusHistory = eventsList
        .whereType<Map<String, dynamic>>()
        .where((event) => event['eventType']?.toString() == 'status_changed')
        .map(StatusTimelineEntry.fromEventJson)
        .toList();

    return AssemblyItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      number: json['number'] as String? ?? 'ASM-${json['id']}',
      status: status,
      statusCode: statusCode,
      statusColor: statusColor,
      date: createdAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tracksCount: tracksCount,
      tariffName: tariff?['name'] as String?,
      packagingName: packaging?['nameRu'] as String?,
      hasFragileGoods:
          json['hasFragileGoods'] == true || json['hasFragileGoods'] == 'true',
      placePreference: json['placePreference']?.toString() ?? 'unspecified',
      boxes: boxes,
      statusHistory: statusHistory,
    );
  }

  String get placePreferenceLabel {
    switch (placePreference) {
      case 'single_if_possible':
        return 'По возможности 1 место';
      case 'split_allowed':
        return 'Можно разделить';
      default:
        return 'Не важно';
    }
  }

  /// Общее количество коробок
  int get boxCount => boxes.length;

  /// Общий вес всех коробок (кг)
  double? get totalWeight {
    if (boxes.isEmpty) return null;
    return boxes.map((b) => b.weight).reduce((a, b) => a + b);
  }

  /// Общий объём всех коробок (м³)
  double? get totalVolume {
    if (boxes.isEmpty) return null;
    return boxes.map((b) => b.volume).reduce((a, b) => a + b);
  }

  /// Средняя плотность (кг/м³)
  double? get averageDensity {
    final weight = totalWeight;
    final volume = totalVolume;
    if (weight == null || volume == null || volume == 0) return null;
    return weight / volume;
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
