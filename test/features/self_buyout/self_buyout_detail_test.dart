import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/payments/data/payment_operator_status.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_models.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_service.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/presentation/self_buyout_screen.dart';

const _request = SelfBuyoutRequest(
  id: 5,
  requestNumber: 'SB-PL-01-07-16-001',
  status: 'completed',
  clientCodeId: 20,
  requestedCnyAmount: 100,
  paymentRubAmount: 1200,
  clientCnyRubRate: 12,
  amountEnteredIn: 'cny',
);

const _cancelledRequest = SelfBuyoutRequest(
  id: 6,
  requestNumber: 'SB-PL-01-07-16-002',
  status: 'cancelled',
  clientCodeId: 20,
  requestedCnyAmount: 200,
  paymentRubAmount: 2400,
  clientCnyRubRate: 12,
  amountEnteredIn: 'cny',
);

class _FakeSelfBuyoutService extends SelfBuyoutService {
  _FakeSelfBuyoutService({this.detail}) : super(ApiClient());

  final SelfBuyoutDetail? detail;

  int detailCalls = 0;
  int correctionCalls = 0;

  @override
  Future<SelfBuyoutAvailability> getAvailability() async =>
      SelfBuyoutAvailability.unavailable;

  @override
  Future<List<SelfBuyoutRequest>> getRequests() async => [
    detail?.request ?? _request,
  ];

  @override
  Future<SelfBuyoutDetail> getDetail(int requestId) async {
    detailCalls++;
    if (detail != null) return detail!;
    return const SelfBuyoutDetail(
      request: _request,
      payment: SelfBuyoutPaymentInfo(
        paymentId: 9,
        status: 'success',
        amountRub: 1200,
        sumKopecks: 120000,
        purpose: 'Самовыкуп',
        qrPayload: '',
        receiptStatus: 'approved',
      ),
      transferProofs: [
        SelfBuyoutTransferProof(
          id: 7,
          fileName: 'proof.jpg',
          mimeType: 'image/jpeg',
          size: 7610,
          fileUrl: '/api/self-buyout/transfer-proofs/7/file',
        ),
      ],
    );
  }

  @override
  Future<Uint8List> getTransferProofBytes(String gatedUrl) async {
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
  }

  @override
  Future<SelfBuyoutRequest> correctTransferRequisites({
    required int requestId,
    required Uint8List fileBytes,
    required String fileName,
    required String fileMime,
  }) async {
    correctionCalls++;
    return const SelfBuyoutRequest(
      id: 6,
      requestNumber: 'SB-PL-01-07-16-002',
      status: 'in_progress',
      clientCodeId: 20,
      requestedCnyAmount: 200,
      paymentRubAmount: 2400,
      clientCnyRubRate: 12,
      amountEnteredIn: 'cny',
      hasTransferQr: true,
    );
  }
}

void main() {
  test('SelfBuyoutDetail parses transfer proof from client detail API', () {
    final detail = SelfBuyoutDetail.fromJson({
      'request': {
        'id': 5,
        'requestNumber': 'SB-PL-01-07-16-001',
        'status': 'completed',
        'clientCodeId': 20,
        'requestedCnyAmount': 100,
        'paymentRubAmount': 1200,
        'clientCnyRubRate': 12,
        'amountEnteredIn': 'cny',
      },
      'payment': null,
      'transferProofs': [
        {
          'id': 7,
          'fileName': 'proof.jpg',
          'mimeType': 'image/jpeg',
          'size': 7610,
          'createdAt': '2026-07-16T12:39:41.499Z',
          'fileUrl': '/api/self-buyout/transfer-proofs/7/file',
        },
      ],
    });

    expect(detail.transferProofs, hasLength(1));
    expect(detail.transferProofs.single.fileName, 'proof.jpg');
    expect(detail.transferProofs.single.createdAt, isNotNull);
  });

  test('SelfBuyoutDetail parses partner cancellation reason', () {
    final detail = SelfBuyoutDetail.fromJson({
      'request': {
        'id': 6,
        'requestNumber': 'SB-PL-01-07-16-002',
        'status': 'cancelled',
        'clientCodeId': 20,
        'requestedCnyAmount': 200,
        'paymentRubAmount': 2400,
        'clientCnyRubRate': 12,
        'amountEnteredIn': 'cny',
      },
      'payment': null,
      'transferProofs': const [],
      'cancellation': {
        'source': 'partner',
        'reason': 'Неверный QR получателя',
        'reasonCode': 'invalid_transfer_requisites',
        'canCorrectRequisites': true,
      },
    });

    expect(detail.cancellation?.source, 'partner');
    expect(detail.cancellation?.reason, 'Неверный QR получателя');
    expect(detail.cancellation?.canCorrectRequisites, isTrue);
  });

  testWidgets('completed request opens detail sheet with transfer proof', (
    tester,
  ) async {
    final service = _FakeSelfBuyoutService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selfBuyoutServiceProvider.overrideWithValue(service),
          paymentOperatorStatusProvider.overrideWith(
            (ref) => Stream.value(PaymentOperatorStatus.workingFallback),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SelfBuyoutScreen())),
      ),
    );
    await tester.pumpAndSettle();

    final requestFinder = find.text('SB-PL-01-07-16-001').first;
    await tester.ensureVisible(requestFinder);
    await tester.tap(requestFinder);
    await tester.pumpAndSettle();

    expect(service.detailCalls, 1);
    expect(find.text('Подтверждение перевода'), findsOneWidget);
    expect(find.text('proof.jpg'), findsOneWidget);
  });

  testWidgets('partner cancellation shows reason and correction action', (
    tester,
  ) async {
    final service = _FakeSelfBuyoutService(
      detail: const SelfBuyoutDetail(
        request: _cancelledRequest,
        cancellation: SelfBuyoutCancellation(
          source: 'partner',
          reason: 'Неверный QR получателя',
          reasonCode: 'invalid_transfer_requisites',
          canCorrectRequisites: true,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selfBuyoutServiceProvider.overrideWithValue(service),
          paymentOperatorStatusProvider.overrideWith(
            (ref) => Stream.value(PaymentOperatorStatus.workingFallback),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SelfBuyoutScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SB-PL-01-07-16-002').first);
    await tester.pumpAndSettle();

    expect(find.text('Неверный QR получателя'), findsOneWidget);
    expect(find.text('Исправить реквизиты'), findsOneWidget);

    await tester.tap(find.text('Исправить реквизиты'));
    await tester.pumpAndSettle();

    expect(find.text('Оплата уже подтверждена'), findsOneWidget);
    expect(find.text('Отправить на рассмотрение'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Приложить QR/изображение'), findsOneWidget);

    await tester.tap(find.text('Отправить на рассмотрение'));
    await tester.pumpAndSettle();

    expect(
      find.text('Приложите новое изображение QR или реквизитов'),
      findsOneWidget,
    );
    expect(service.correctionCalls, 0);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('full partner cancellation does not show correction action', (
    tester,
  ) async {
    final service = _FakeSelfBuyoutService(
      detail: const SelfBuyoutDetail(
        request: _cancelledRequest,
        cancellation: SelfBuyoutCancellation(
          source: 'partner',
          reason: 'Операция полностью отменена',
          reasonCode: 'other',
          canCorrectRequisites: false,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selfBuyoutServiceProvider.overrideWithValue(service),
          paymentOperatorStatusProvider.overrideWith(
            (ref) => Stream.value(PaymentOperatorStatus.workingFallback),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SelfBuyoutScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SB-PL-01-07-16-002').first);
    await tester.pumpAndSettle();

    expect(find.text('Операция полностью отменена'), findsOneWidget);
    expect(find.text('Исправить реквизиты'), findsNothing);
    expect(find.text('Закрыть'), findsOneWidget);
  });
}
