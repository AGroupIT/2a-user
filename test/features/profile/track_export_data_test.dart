import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/profile/data/track_export_data.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/track_item.dart';

void main() {
  test('формирует запрошенные колонки трека и данные фотоотчёта', () {
    final createdAt = DateTime.utc(2026, 8, 26, 12);
    final track = TrackItem(
      code: 'TRACK-1',
      status: 'На складе',
      date: createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
      invoiceNumber: '2A-01-DS-08-26-1',
      productInfo: const ProductInfo(
        name: 'Кроссовки',
        quantity: 2,
        imageUrl: '/uploads/product.jpg',
      ),
      photoReportUrls: const ['/uploads/report-legacy.jpg'],
      photoRequests: [
        PhotoRequest(
          id: 1,
          status: 'completed',
          mediaUrls: const ['/uploads/report.jpg'],
          createdAt: createdAt,
        ),
      ],
    );

    final row = buildTrackExportRow(track);

    expect(trackExportHeaders, hasLength(9));
    expect(row.values, [
      'TRACK-1',
      '26.08.2026',
      'На складе',
      '2A-01-DS-08-26-1',
      '',
      'Кроссовки',
      2,
      'Выполнен',
      '2 фото',
    ]);
    expect(row.productImageUrl, '/uploads/product.jpg');
    expect(row.photoReportUrls, [
      '/uploads/report.jpg',
      '/uploads/report-legacy.jpg',
    ]);
  });
}
