import 'package:intl/intl.dart';

import '../../tracks/domain/track_item.dart';

const trackExportHeaders = <String>[
  'Трек-номер',
  'Дата создания',
  'Статус',
  'Связанный счёт',
  'Фото товара',
  'Название товара',
  'Количество',
  'Статус фотоотчёта',
  'Фотографии фотоотчёта',
];

class TrackExportRow {
  final List<Object> values;
  final String? productImageUrl;
  final List<String> photoReportUrls;

  const TrackExportRow({
    required this.values,
    this.productImageUrl,
    this.photoReportUrls = const [],
  });
}

TrackExportRow buildTrackExportRow(TrackItem track) {
  final photoRequest = track.photoRequests
      .where((request) => request.status != 'cancelled')
      .firstOrNull;
  final reportUrls = <String>{
    ...?photoRequest?.mediaUrls,
    ...track.photoReportUrls,
  }.where((url) => url.trim().isNotEmpty).toList();

  return TrackExportRow(
    values: [
      track.code,
      DateFormat('dd.MM.yyyy').format(track.createdAt.toLocal()),
      track.status,
      track.invoiceNumber ?? '',
      '',
      track.productInfo?.name ?? '',
      track.productInfo?.quantity ?? 0,
      photoRequest?.statusLabel ?? '',
      reportUrls.isEmpty ? '' : '${reportUrls.length} фото',
    ],
    productImageUrl: track.productInfo?.imageUrl,
    photoReportUrls: reportUrls,
  );
}
