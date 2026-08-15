import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'sp_organizer_analytics_models.dart';
import 'sp_organizer_calculation_models.dart';
import 'sp_organizer_customer_models.dart';
import 'sp_organizer_export_models.dart';
import 'sp_organizer_fulfillment_models.dart';
import 'sp_organizer_garage_import_models.dart';
import 'sp_organizer_models.dart';
import 'sp_organizer_previous_purchase_models.dart';
import 'sp_organizer_purchase_blank_models.dart';
import 'sp_organizer_track_import_models.dart';

Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

class SpOrganizerRepository {
  final ApiClient _apiClient;

  const SpOrganizerRepository(this._apiClient);

  Future<SpOrganizerCapabilities> getCapabilities() async {
    try {
      final response = await _apiClient.get('/client/sp-v2/capabilities');
      return SpOrganizerCapabilities.fromJson(_mapValue(response.data));
    } on DioException catch (error) {
      debugPrint('SP organizer capabilities unavailable: $error');
      return SpOrganizerCapabilities.unavailable;
    } catch (error) {
      debugPrint('SP organizer capabilities response is invalid: $error');
      return SpOrganizerCapabilities.unavailable;
    }
  }

  Future<SpOrganizerAnalytics> getAnalytics(
    SpOrganizerAnalyticsFilter filter,
  ) async {
    String? dateValue(DateTime? value) {
      if (value == null) return null;
      final year = value.year.toString().padLeft(4, '0');
      final month = value.month.toString().padLeft(2, '0');
      final day = value.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }

    final response = await _apiClient.get(
      '/client/sp-v2/analytics',
      queryParameters: {
        'period': filter.period,
        'audience': filter.audience,
        'kind': filter.kind,
        'selfItemsAsPersonal': filter.selfItemsAsPersonal,
        if (dateValue(filter.dateFrom) case final value?) 'dateFrom': value,
        if (dateValue(filter.dateTo) case final value?) 'dateTo': value,
      },
    );
    return SpOrganizerAnalytics.fromJson(_mapValue(response.data));
  }

  Future<SpOrganizerPurchaseExport> getPurchaseExport(int purchaseId) async {
    final response = await _apiClient.get(
      '/client/sp-v2/purchases/$purchaseId/export',
    );
    return SpOrganizerPurchaseExport.fromJson(_mapValue(response.data));
  }

  Future<SpOrganizerCustomerPage> getCustomersDirectory({
    String? query,
    String scope = 'active',
    int page = 1,
    int limit = 30,
    String sortBy = 'fullName',
    String sortDirection = 'asc',
  }) async {
    final response = await _apiClient.get(
      '/client/sp-v2/organizer/customers',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'scope': scope,
        'page': page,
        'limit': limit,
        'sortBy': sortBy,
        'sortDirection': sortDirection,
      },
    );
    return SpOrganizerCustomerPage.fromJson(_mapValue(response.data));
  }

  Future<SpOrganizerCustomerDetail> getCustomerDetail(
    int customerId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/client/sp-v2/organizer/customers/$customerId',
      queryParameters: {'page': page, 'limit': limit},
    );
    return SpOrganizerCustomerDetail.fromJson(_mapValue(response.data));
  }

  Future<SpOrganizerCustomer> archiveCustomer(
    int customerId, {
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/organizer/customers/$customerId/archive',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return SpOrganizerCustomer.fromJson(
      _mapValue(_mapValue(response.data)['customer']),
    );
  }

  Future<SpOrganizerCustomer> restoreCustomer(int customerId) async {
    final response = await _apiClient.post(
      '/client/sp-v2/organizer/customers/$customerId/restore',
    );
    return SpOrganizerCustomer.fromJson(
      _mapValue(_mapValue(response.data)['customer']),
    );
  }

  Future<SpOrganizerProductPage> getProducts({
    String? query,
    int page = 1,
    int limit = 40,
    bool includeArchived = false,
    String sortBy = 'title',
    String sortDirection = 'asc',
  }) async {
    final response = await _apiClient.get(
      '/client/sp-v2/products',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'limit': limit,
        if (includeArchived) 'includeArchived': true,
        'sortBy': sortBy,
        'sortDirection': sortDirection,
      },
    );
    return SpOrganizerProductPage.fromJson(_mapValue(response.data));
  }

  Future<SpOrganizerProductDetail> getProductDetail(
    SpOrganizerProductDetailQuery query,
  ) async {
    final response = await _apiClient.get(
      '/client/sp-v2/products/${query.productId}',
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'q': query.query.trim(),
        if (query.status != null && query.status!.trim().isNotEmpty)
          'status': query.status,
        'scope': query.scope,
        'page': query.page,
        'limit': query.limit,
        'sortBy': query.sortBy,
        'sortDirection': query.sortDirection,
      },
    );
    return SpOrganizerProductDetail.fromJson(_mapValue(response.data));
  }

  Future<SpOrganizerPurchaseBlankCandidatePage>
  getPurchaseBlankImportCandidates({
    required int purchaseId,
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/client/sp-v2/purchases/$purchaseId/items/import/purchase-blank',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'limit': limit,
      },
    );
    return SpOrganizerPurchaseBlankCandidatePage.fromJson(
      _mapValue(response.data),
    );
  }

  Future<bool> importPurchaseBlankItem({
    required int purchaseId,
    required int purchaseBlankItemId,
    required int customerId,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/purchases/$purchaseId/items/import/purchase-blank',
      data: {
        'purchaseBlankItemId': purchaseBlankItemId,
        'spCustomerId': customerId,
      },
    );
    return _mapValue(response.data)['imported'] == true;
  }

  Future<SpOrganizerPreviousPurchaseCandidatePage>
  getPreviousPurchaseImportCandidates({
    required int purchaseId,
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/client/sp-v2/purchases/$purchaseId/items/import/previous-purchase',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'limit': limit,
      },
    );
    return SpOrganizerPreviousPurchaseCandidatePage.fromJson(
      _mapValue(response.data),
    );
  }

  Future<bool> importPreviousPurchaseItem({
    required int purchaseId,
    required int sourceSpItemId,
    required int customerId,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/purchases/$purchaseId/items/import/previous-purchase',
      data: {'sourceSpItemId': sourceSpItemId, 'spCustomerId': customerId},
    );
    return _mapValue(response.data)['imported'] == true;
  }

  Future<SpOrganizerGarageImportCandidatePage> getGarageImportCandidates({
    required int purchaseId,
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/client/sp-v2/purchases/$purchaseId/items/import/garage',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'limit': limit,
      },
    );
    return SpOrganizerGarageImportCandidatePage.fromJson(
      _mapValue(response.data),
    );
  }

  Future<bool> importGarageItem({
    required int purchaseId,
    required int garageOrderItemId,
    required int customerId,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/purchases/$purchaseId/items/import/garage',
      data: {
        'garageOrderItemId': garageOrderItemId,
        'spCustomerId': customerId,
      },
    );
    return _mapValue(response.data)['imported'] == true;
  }

  Future<SpOrganizerTrackImportCandidatePage> getTrackImportCandidates({
    required int purchaseId,
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/client/sp-v2/purchases/$purchaseId/items/import/track',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'limit': limit,
      },
    );
    return SpOrganizerTrackImportCandidatePage.fromJson(
      _mapValue(response.data),
    );
  }

  Future<bool> importTrackItem({
    required int purchaseId,
    required int trackId,
    required int customerId,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/purchases/$purchaseId/items/import/track',
      data: {'trackId': trackId, 'spCustomerId': customerId},
    );
    return _mapValue(response.data)['imported'] == true;
  }

  Future<SpOrganizerProduct> createProduct(
    SpOrganizerProductInput input,
  ) async {
    final response = await _apiClient.post(
      '/client/sp-v2/products',
      data: input.toJson(),
    );
    return SpOrganizerProduct.fromJson(
      _mapValue(_mapValue(response.data)['product']),
    );
  }

  Future<SpOrganizerProduct> updateProduct(
    int productId,
    SpOrganizerProductInput input,
  ) async {
    final response = await _apiClient.patch(
      '/client/sp-v2/products/$productId',
      data: input.toUpdateJson(),
    );
    return SpOrganizerProduct.fromJson(
      _mapValue(_mapValue(response.data)['product']),
    );
  }

  Future<SpOrganizerProduct> archiveProduct(
    int productId, {
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/products/$productId/archive',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return SpOrganizerProduct.fromJson(
      _mapValue(_mapValue(response.data)['product']),
    );
  }

  Future<SpOrganizerProduct> restoreProduct(int productId) async {
    final response = await _apiClient.post(
      '/client/sp-v2/products/$productId/restore',
    );
    return SpOrganizerProduct.fromJson(
      _mapValue(_mapValue(response.data)['product']),
    );
  }

  Future<SpOrganizerParticipantList> getParticipants(
    int purchaseId, {
    bool includeArchived = false,
  }) async {
    final response = await _apiClient.get(
      '/client/sp-v2/purchases/$purchaseId/participants',
      queryParameters: {if (includeArchived) 'includeArchived': true},
    );
    return SpOrganizerParticipantList.fromJson(_mapValue(response.data));
  }

  Future<SpOrganizerParticipant> saveParticipant(
    int purchaseId, {
    int? customerId,
    bool self = false,
    int? displayOrder,
    String? note,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/purchases/$purchaseId/participants',
      data: {
        if (customerId != null) 'spCustomerId': customerId,
        if (self) 'self': true,
        if (displayOrder != null) 'displayOrder': displayOrder,
        if (note != null) 'note': note,
      },
    );
    return SpOrganizerParticipant.fromJson(
      _mapValue(_mapValue(response.data)['participant']),
    );
  }

  Future<SpOrganizerParticipant> updateParticipant(
    int participantId, {
    int? displayOrder,
    String? note,
    bool? archived,
    String? archivedReason,
  }) async {
    final response = await _apiClient.patch(
      '/client/sp-v2/participants/$participantId',
      data: {
        if (displayOrder != null) 'displayOrder': displayOrder,
        if (note != null) 'note': note,
        if (archived != null) 'archived': archived,
        if (archivedReason != null) 'archivedReason': archivedReason,
      },
    );
    return SpOrganizerParticipant.fromJson(
      _mapValue(_mapValue(response.data)['participant']),
    );
  }

  Future<SpOrganizerCalculationPreview> getCalculationPreview(
    int purchaseId, {
    SpOrganizerCalculationProfileInput? profileOverride,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/purchases/$purchaseId/calculation/preview',
      data: {
        if (profileOverride != null) ...{
          'scope': profileOverride.scope,
          'profile': profileOverride.toJson(includeScope: false),
        },
      },
    );
    return SpOrganizerCalculationPreview.fromJson(_mapValue(response.data));
  }

  Future<void> saveCalculationProfile(
    int purchaseId,
    SpOrganizerCalculationProfileInput input,
  ) async {
    await _apiClient.patch(
      '/client/sp-v2/purchases/$purchaseId/calculation/profile',
      data: input.toJson(),
    );
  }

  Future<SpOrganizerCalculationActionResult> applyCalculation(
    int purchaseId, {
    required String inputHash,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/purchases/$purchaseId/calculation/apply',
      data: {'inputHash': inputHash},
    );
    return SpOrganizerCalculationActionResult.fromJson(
      _mapValue(response.data),
    );
  }

  Future<SpOrganizerCalculationActionResult> actualizeCalculation(
    int purchaseId, {
    required int expectedAppliedSnapshotId,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/purchases/$purchaseId/calculation/actualize',
      data: {'expectedAppliedSnapshotId': expectedAppliedSnapshotId},
    );
    return SpOrganizerCalculationActionResult.fromJson(
      _mapValue(response.data),
    );
  }

  Future<SpOrganizerAllocationPostingActionResult> postCalculationAllocation(
    int purchaseId, {
    required int expectedAppliedSnapshotId,
  }) async {
    final response = await _apiClient.post(
      '/client/sp-v2/purchases/$purchaseId/calculation/posting',
      data: {'expectedAppliedSnapshotId': expectedAppliedSnapshotId},
    );
    return SpOrganizerAllocationPostingActionResult.fromJson(
      _mapValue(response.data),
    );
  }

  Future<SpOrganizerFulfillmentOverview> getFulfillmentOverview(
    int purchaseId,
  ) async {
    final response = await _apiClient.get(
      '/client/sp-v2/purchases/$purchaseId/fulfillment',
    );
    return SpOrganizerFulfillmentOverview.fromJson(_mapValue(response.data));
  }

  Future<SpOrganizerFulfillmentCandidatePage> getFulfillmentCandidates({
    required int purchaseId,
    required SpOrganizerFulfillmentLinkKind kind,
    int? itemId,
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/client/sp-v2/purchases/$purchaseId/fulfillment/candidates',
      queryParameters: {
        'kind': kind.apiValue,
        if (itemId != null) 'itemId': itemId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'limit': limit,
      },
    );
    return SpOrganizerFulfillmentCandidatePage.fromJson(
      _mapValue(response.data),
    );
  }

  Future<void> linkFulfillmentCandidate({
    required int purchaseId,
    required SpOrganizerFulfillmentLinkKind kind,
    required int targetId,
    int? itemId,
  }) async {
    final field = switch (kind) {
      SpOrganizerFulfillmentLinkKind.selfBuyout => 'selfBuyoutRequestId',
      SpOrganizerFulfillmentLinkKind.garage => 'garageOrderItemId',
      SpOrganizerFulfillmentLinkKind.track => 'trackId',
      SpOrganizerFulfillmentLinkKind.assembly => 'assemblyId',
      SpOrganizerFulfillmentLinkKind.invoice => 'invoiceId',
    };
    if (kind.itemScoped) {
      if (itemId == null) {
        throw ArgumentError('itemId is required for ${kind.apiValue}');
      }
      await _apiClient.post(
        '/client/sp-v2/items/$itemId/link/${kind.apiValue}',
        data: {field: targetId},
      );
      return;
    }
    await _apiClient.post(
      '/client/sp-v2/purchases/$purchaseId/link/${kind.apiValue}',
      data: {field: targetId},
    );
  }
}
