import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'purchase_blank_model.dart';

// ─── State ───────────────────────────────────────────────

class PurchaseBlanksState {
  final List<PurchaseBlank> blanks;
  final bool isLoading;
  final String? error;

  const PurchaseBlanksState({
    this.blanks = const [],
    this.isLoading = false,
    this.error,
  });

  PurchaseBlanksState copyWith({
    List<PurchaseBlank>? blanks,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PurchaseBlanksState(
      blanks: blanks ?? this.blanks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Notifier ────────────────────────────────────────────

class PurchaseBlanksNotifier extends Notifier<PurchaseBlanksState> {
  @override
  PurchaseBlanksState build() {
    return const PurchaseBlanksState();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  /// Загрузить список бланков клиента
  Future<void> loadBlanks() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.get('/client/purchase-blanks');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List<dynamic>? ?? [])
            .map((e) => PurchaseBlank.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(blanks: list, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('[PurchaseBlanks] Error loading: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Ошибка загрузки бланков',
      );
    }
  }

  /// Создать новый бланк (черновик)
  Future<PurchaseBlank?> createBlank({
    List<Map<String, dynamic>> items = const [],
  }) async {
    try {
      final response = await _api.post('/client/purchase-blanks', data: {
        'items': items,
      });

      if (response.statusCode == 201 && response.data?['data'] != null) {
        final blank = PurchaseBlank.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = state.copyWith(blanks: [blank, ...state.blanks]);
        return blank;
      }
    } catch (e) {
      debugPrint('[PurchaseBlanks] Error creating: $e');
    }
    return null;
  }

  /// Получить детали бланка
  Future<PurchaseBlank?> getBlank(int blankId) async {
    try {
      final response = await _api.get('/client/purchase-blanks/$blankId');
      if (response.statusCode == 200 && response.data?['data'] != null) {
        return PurchaseBlank.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[PurchaseBlanks] Error loading blank $blankId: $e');
    }
    return null;
  }

  /// Добавить товар в бланк
  Future<PurchaseBlankItem?> addItem(
    int blankId, {
    required String productName,
    required String productUrl,
    String? characteristics,
    int quantity = 1,
    required double unitPrice,
  }) async {
    try {
      final response = await _api.post(
        '/client/purchase-blanks/$blankId/items',
        data: {
          'productName': productName,
          'productUrl': productUrl,
          if (characteristics != null) 'characteristics': characteristics,
          'quantity': quantity,
          'unitPrice': unitPrice,
        },
      );

      if (response.statusCode == 201 && response.data?['data'] != null) {
        return PurchaseBlankItem.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[PurchaseBlanks] Error adding item: $e');
    }
    return null;
  }

  /// Обновить товар
  Future<PurchaseBlankItem?> updateItem(
    int blankId,
    int itemId, {
    String? productName,
    String? productUrl,
    String? characteristics,
    int? quantity,
    double? unitPrice,
  }) async {
    try {
      final response = await _api.put(
        '/client/purchase-blanks/$blankId/items/$itemId',
        data: {
          if (productName != null) 'productName': productName,
          if (productUrl != null) 'productUrl': productUrl,
          if (characteristics != null) 'characteristics': characteristics,
          if (quantity != null) 'quantity': quantity,
          if (unitPrice != null) 'unitPrice': unitPrice,
        },
      );

      if (response.statusCode == 200 && response.data?['data'] != null) {
        return PurchaseBlankItem.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[PurchaseBlanks] Error updating item: $e');
    }
    return null;
  }

  /// Удалить товар
  Future<bool> deleteItem(int blankId, int itemId) async {
    try {
      final response = await _api.delete(
        '/client/purchase-blanks/$blankId/items/$itemId',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[PurchaseBlanks] Error deleting item: $e');
      return false;
    }
  }

  /// Загрузить фото для товара
  Future<String?> uploadItemPhoto(
    int blankId,
    int itemId,
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });

      final response = await _api.post(
        '/client/purchase-blanks/$blankId/items/$itemId/photos',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data?['url'] as String?;
      }
    } catch (e) {
      debugPrint('[PurchaseBlanks] Error uploading photo: $e');
    }
    return null;
  }

  /// Отправить бланк на обработку
  Future<bool> submitBlank(int blankId) async {
    try {
      final response =
          await _api.post('/client/purchase-blanks/$blankId/submit');

      if (response.statusCode == 200) {
        // Обновляем статус в списке
        final updated = state.blanks.map((b) {
          if (b.id == blankId) {
            return PurchaseBlank.fromJson({
              ...{'id': b.id, 'clientId': b.clientId, 'agentId': b.agentId},
              'status': 'submitted',
              'createdAt': b.createdAt.toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            });
          }
          return b;
        }).toList();
        state = state.copyWith(blanks: updated);
        return true;
      }
    } catch (e) {
      debugPrint('[PurchaseBlanks] Error submitting: $e');
    }
    return false;
  }

  /// Отменить бланк
  Future<bool> cancelBlank(int blankId) async {
    try {
      final response =
          await _api.post('/client/purchase-blanks/$blankId/cancel');

      if (response.statusCode == 200) {
        final updated = state.blanks.map((b) {
          if (b.id == blankId) {
            return PurchaseBlank.fromJson({
              ...{'id': b.id, 'clientId': b.clientId, 'agentId': b.agentId},
              'status': 'cancelled',
              'createdAt': b.createdAt.toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            });
          }
          return b;
        }).toList();
        state = state.copyWith(blanks: updated);
        return true;
      }
    } catch (e) {
      debugPrint('[PurchaseBlanks] Error cancelling: $e');
    }
    return false;
  }

  /// Перезагрузить список
  Future<void> reload() async {
    await loadBlanks();
  }
}

// ─── Provider ────────────────────────────────────────────

final purchaseBlanksProvider =
    NotifierProvider<PurchaseBlanksNotifier, PurchaseBlanksState>(
  PurchaseBlanksNotifier.new,
);

/// Детали конкретного бланка (с товарами)
final purchaseBlankDetailProvider =
    FutureProvider.family<PurchaseBlank?, int>((ref, blankId) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.get('/client/purchase-blanks/$blankId');
    if (response.statusCode == 200 && response.data?['data'] != null) {
      return PurchaseBlank.fromJson(
          response.data['data'] as Map<String, dynamic>);
    }
  } catch (e) {
    debugPrint('[PurchaseBlanks] Error loading detail: $e');
  }
  return null;
});
