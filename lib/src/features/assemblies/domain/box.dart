import '../../../core/utils/locale_text.dart';
import 'package:flutter/material.dart';

/// Фото на весах (упрощённая модель для коробок)
class BoxPhoto {
  final String id;
  final String url;
  final String? comment;

  const BoxPhoto({
    required this.id,
    required this.url,
    this.comment,
  });

  factory BoxPhoto.fromJson(Map<String, dynamic> json) {
    return BoxPhoto(
      id: json['id']?.toString() ?? '',
      url: json['url'] as String? ?? '',
      comment: json['comment'] as String?,
    );
  }
}

/// Коробка в сборке
class Box {
  final int id;
  final int number;
  final double height;
  final double width;
  final double length;
  final double weight;
  final List<BoxPhoto> photos;
  final String? orderNumber;
  final String? tariffName;
  final List<String> packagingTypes;

  const Box({
    required this.id,
    required this.number,
    required this.height,
    required this.width,
    required this.length,
    required this.weight,
    this.photos = const [],
    this.orderNumber,
    this.tariffName,
    this.packagingTypes = const [],
  });

  factory Box.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Парсим типы упаковки
    List<String> parsePackaging(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      return [];
    }

    return Box(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      number: json['number'] as int? ?? 1,
      height: parseDouble(json['height']),
      width: parseDouble(json['width']),
      length: parseDouble(json['length']),
      weight: parseDouble(json['weight']),
      photos: (json['scalePhotos'] as List<dynamic>?)
              ?.map((p) => BoxPhoto.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      orderNumber: json['orderNumber'] as String?,
      tariffName: json['tariffName'] as String? ??
          (json['tariff'] as Map<String, dynamic>?)?['name'] as String?,
      packagingTypes: parsePackaging(json['packagingTypeNames']),
    );
  }

  /// Вычисленный объём в м³ (height * width * length / 1000000)
  double get volume {
    return (height * width * length) / 1000000;
  }

  /// Вычисленная плотность в кг/м³ (weight / volume)
  double get density {
    final vol = volume;
    if (vol == 0) return 0;
    return weight / vol;
  }

  /// Отображаемое название "Коробка #1" / "箱子 #1"
  String displayName(BuildContext context) {
    return tr(context, ru: 'Коробка #$number', zh: '箱子 #$number');
  }

  /// Отображение габаритов "50×40×30 см"
  String get dimensionsDisplay {
    return '${height.toStringAsFixed(0)}×${width.toStringAsFixed(0)}×${length.toStringAsFixed(0)} см';
  }

  /// Отображение веса "12.5 кг"
  String get weightDisplay {
    return '${weight.toStringAsFixed(1)} кг';
  }

  /// Отображение объёма "0.06 м³"
  String get volumeDisplay {
    return '${volume.toStringAsFixed(4)} м³';
  }

  /// Отображение плотности "208.3 кг/м³"
  String get densityDisplay {
    return '${density.toStringAsFixed(1)} кг/м³';
  }
}
