import 'track_item.dart';

enum ProductInfoCompleteness { complete, missingNameOrQuantity, missingPhoto }

/// Only persisted ProductInfo.imageUrl counts, never draft pictures or reports.
ProductInfoCompleteness productInfoCompleteness(Iterable<ProductInfo> rows) {
  final values = rows.toList(growable: false);
  if (values.isEmpty ||
      values.any(
        (row) => (row.name?.trim().isEmpty ?? true) || row.quantity <= 0,
      )) {
    return ProductInfoCompleteness.missingNameOrQuantity;
  }
  if (values.any((row) => !_hasSavedPhoto(row.imageUrl))) {
    return ProductInfoCompleteness.missingPhoto;
  }
  return ProductInfoCompleteness.complete;
}

bool _hasSavedPhoto(String? value) =>
    value != null &&
    RegExp(
      r'^(https?://[^\s/]+/\S+|/(?!/)\S+)$',
      caseSensitive: false,
    ).hasMatch(value.trim());
