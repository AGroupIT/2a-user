import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_calculation_models.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_provider.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/presentation/sp_organizer_calculation_panel.dart';

const _preview = SpOrganizerCalculationPreview(
  contractVersion: 1,
  engine: 'legacy_v1_shadow',
  mode: 'preview',
  persisted: false,
  inputHash: 'test-hash',
  effectiveProfile: SpOrganizerCalculationProfile(
    source: 'legacy',
    scope: 'client',
    currency: 'CNY',
    cnyRubRate: 12.5,
  ),
  effectiveSelfProfile: SpOrganizerCalculationProfile(
    source: 'profile',
    scope: 'self',
    currency: 'CNY',
    cnyRubRate: 12.2,
    usdRubRate: 87,
    pricePerKg: 3.4,
    pricePerKgCurrency: 'USD',
    parcelWeightKg: 0.15,
  ),
  effectiveClientProfile: SpOrganizerCalculationProfile(
    source: 'profile',
    scope: 'client',
    currency: 'CNY',
    cnyRubRate: 12.5,
    commissionMode: 'percent',
    commissionPercent: 5,
    commissionBase: 'goods',
  ),
  referencePreview: SpOrganizerReferenceCalculationPreview(
    contractVersion: 1,
    mode: 'read_only',
    persisted: false,
    allocationApplied: false,
    complete: false,
    self: SpOrganizerReferenceCalculationScope(
      scope: 'self',
      complete: true,
      goodsRub: 244,
      weightKg: 0.15,
      internationalDeliveryRub: 44.37,
      packingRub: 0,
      insuranceRub: 0,
      domesticDeliveryRub: 0,
      additionalExpensesRub: 0,
      commissionRub: 0,
      totalRub: 288.37,
    ),
    client: SpOrganizerReferenceCalculationScope(
      scope: 'client',
      complete: false,
      goodsRub: 500,
      weightKg: 0,
      internationalDeliveryRub: 0,
      packingRub: 0,
      insuranceRub: 0,
      domesticDeliveryRub: 0,
      additionalExpensesRub: 0,
      commissionRub: 25,
      totalRub: 525,
      missingRequirements: ['client_weight'],
    ),
    expectedProfitRub: 236.63,
    allocation: SpOrganizerReferenceAllocation(
      method: 'owned_goods_and_weight',
      rounding: 'largest_remainder_by_sp_customer_id',
      persisted: false,
      applied: false,
      complete: false,
      totalsMatch: true,
      allocatedSelfRub: 288.37,
      allocatedClientRub: 525,
      participants: [
        SpOrganizerReferenceParticipantAllocation(
          spCustomerId: 7,
          displayName: 'Анна',
          isOrganizerSelf: false,
          itemsCount: 2,
          self: SpOrganizerReferenceParticipantScope(
            goodsRub: 244,
            internationalDeliveryRub: 44.37,
            packingRub: 0,
            insuranceRub: 0,
            domesticDeliveryRub: 0,
            additionalExpensesRub: 0,
            commissionRub: 0,
            totalRub: 288.37,
          ),
          client: SpOrganizerReferenceParticipantScope(
            goodsRub: 500,
            internationalDeliveryRub: 0,
            packingRub: 0,
            insuranceRub: 0,
            domesticDeliveryRub: 0,
            additionalExpensesRub: 0,
            commissionRub: 25,
            totalRub: 525,
          ),
          expectedProfitRub: 236.63,
        ),
      ],
    ),
  ),
  summary: SpOrganizerCalculationSummary(
    participantsCount: 1,
    itemsCount: 2,
    goodsDueRub: 500,
    goodsPaidRub: 200,
    deliveryDueRub: 100,
    deliveryPaidRub: 50,
    extraDueRub: 20,
    extraPaidRub: 0,
    totalDueRub: 620,
    paidRub: 250,
    totalProfitRub: 130,
  ),
  participants: [
    SpOrganizerParticipantCalculation(
      spCustomerId: 7,
      displayName: 'Анна',
      isOrganizerSelf: false,
      itemsCount: 2,
      totalDueRub: 620,
      paidRub: 250,
      balanceRub: 370,
    ),
  ],
  unallocatedExpensesRub: 20,
  unassignedPaidRub: 0,
  organizerTo2A: SpOrganizerTo2AObligation(
    available: false,
    linked: false,
    reason: 'fulfillment_not_linked',
  ),
  matchesLegacy: true,
  canApplyCalculation: true,
  warnings: ['organizer_2a_obligation_not_linked'],
);

final _fixedReferencePreview = SpOrganizerReferenceCalculationPreview(
  contractVersion: _preview.referencePreview!.contractVersion,
  mode: _preview.referencePreview!.mode,
  persisted: true,
  allocationApplied: true,
  complete: true,
  self: _preview.referencePreview!.self,
  client: SpOrganizerReferenceCalculationScope(
    scope: _preview.referencePreview!.client.scope,
    complete: true,
    goodsRub: _preview.referencePreview!.client.goodsRub,
    weightKg: 2,
    internationalDeliveryRub:
        _preview.referencePreview!.client.internationalDeliveryRub,
    packingRub: _preview.referencePreview!.client.packingRub,
    insuranceRub: _preview.referencePreview!.client.insuranceRub,
    domesticDeliveryRub: _preview.referencePreview!.client.domesticDeliveryRub,
    additionalExpensesRub:
        _preview.referencePreview!.client.additionalExpensesRub,
    commissionRub: _preview.referencePreview!.client.commissionRub,
    totalRub: _preview.referencePreview!.client.totalRub,
  ),
  expectedProfitRub: _preview.referencePreview!.expectedProfitRub,
  allocation: SpOrganizerReferenceAllocation(
    method: _preview.referencePreview!.allocation!.method,
    rounding: _preview.referencePreview!.allocation!.rounding,
    persisted: true,
    applied: true,
    ledgerPosted: false,
    complete: true,
    totalsMatch: _preview.referencePreview!.allocation!.totalsMatch,
    allocatedSelfRub: _preview.referencePreview!.allocation!.allocatedSelfRub,
    allocatedClientRub:
        _preview.referencePreview!.allocation!.allocatedClientRub,
    participants: _preview.referencePreview!.allocation!.participants,
  ),
);

final _appliedPreview = SpOrganizerCalculationPreview(
  contractVersion: _preview.contractVersion,
  engine: _preview.engine,
  mode: _preview.mode,
  persisted: _preview.persisted,
  inputHash: _preview.inputHash,
  effectiveProfile: _preview.effectiveProfile,
  effectiveSelfProfile: _preview.effectiveSelfProfile,
  effectiveClientProfile: _preview.effectiveClientProfile,
  referencePreview: _fixedReferencePreview,
  summary: _preview.summary,
  participants: _preview.participants,
  unallocatedExpensesRub: _preview.unallocatedExpensesRub,
  unassignedPaidRub: _preview.unassignedPaidRub,
  organizerTo2A: const SpOrganizerTo2AObligation(
    available: true,
    linked: true,
    amountRub: 2355,
    mayContainOverlaps: true,
    breakdown: SpOrganizerTo2ABreakdown(
      selfBuyoutRub: 1300,
      garageRub: 715,
      invoicesRub: 340,
    ),
    actualizedSnapshot: SpOrganizerCalculationSnapshotSummary(
      id: 12,
      version: 2,
      mode: 'actualized',
      inputHash: 'actualized-hash',
    ),
  ),
  matchesLegacy: _preview.matchesLegacy,
  currentAppliedSnapshot: const SpOrganizerCalculationSnapshotSummary(
    id: 11,
    version: 1,
    mode: 'applied',
    inputHash: 'test-hash',
  ),
  latestAppliedSnapshot: const SpOrganizerCalculationSnapshotSummary(
    id: 11,
    version: 1,
    mode: 'applied',
    inputHash: 'test-hash',
  ),
  latestActualizedSnapshot: const SpOrganizerCalculationSnapshotSummary(
    id: 12,
    version: 2,
    mode: 'actualized',
    inputHash: 'actualized-hash',
  ),
  calculationAlreadyApplied: true,
  canPostAllocation: true,
  postingRequiresApply: false,
  canActualizeCalculation: true,
  warnings: const [
    'organizer_2a_obligation_not_linked',
    'profile_ledger_pending_explicit_posting',
  ],
);

final _postedReferencePreview = SpOrganizerReferenceCalculationPreview(
  contractVersion: _fixedReferencePreview.contractVersion,
  mode: _fixedReferencePreview.mode,
  persisted: true,
  allocationApplied: true,
  complete: true,
  self: _fixedReferencePreview.self,
  client: _fixedReferencePreview.client,
  expectedProfitRub: _fixedReferencePreview.expectedProfitRub,
  allocation: SpOrganizerReferenceAllocation(
    method: _fixedReferencePreview.allocation!.method,
    rounding: _fixedReferencePreview.allocation!.rounding,
    persisted: true,
    applied: true,
    ledgerPosted: true,
    complete: true,
    totalsMatch: true,
    allocatedSelfRub: _fixedReferencePreview.allocation!.allocatedSelfRub,
    allocatedClientRub: _fixedReferencePreview.allocation!.allocatedClientRub,
    participants: _fixedReferencePreview.allocation!.participants,
  ),
);

final _postedPreview = SpOrganizerCalculationPreview(
  contractVersion: _appliedPreview.contractVersion,
  engine: _appliedPreview.engine,
  mode: _appliedPreview.mode,
  persisted: _appliedPreview.persisted,
  inputHash: _appliedPreview.inputHash,
  effectiveProfile: _appliedPreview.effectiveProfile,
  effectiveSelfProfile: _appliedPreview.effectiveSelfProfile,
  effectiveClientProfile: _appliedPreview.effectiveClientProfile,
  referencePreview: _postedReferencePreview,
  postedAllocation: const SpOrganizerPostedAllocation(
    id: 21,
    version: 1,
    appliedSnapshotId: 11,
    inputHash: 'test-hash',
    stale: false,
    legacyPaymentsApplied: false,
    totalSelfRub: 288.37,
    totalDueRub: 525,
    totalPaidRub: 0,
    balanceRub: 525,
    expectedProfitRub: 236.63,
    participants: [
      SpOrganizerPostedAllocationParticipant(
        spCustomerId: 7,
        displayName: 'Анна',
        isOrganizerSelf: false,
        itemsCount: 2,
        selfRub: 288.37,
        dueRub: 525,
        paidRub: 0,
        balanceRub: 525,
        expectedProfitRub: 236.63,
      ),
    ],
  ),
  summary: _appliedPreview.summary,
  participants: _appliedPreview.participants,
  unallocatedExpensesRub: _appliedPreview.unallocatedExpensesRub,
  unassignedPaidRub: _appliedPreview.unassignedPaidRub,
  organizerTo2A: _appliedPreview.organizerTo2A,
  matchesLegacy: _appliedPreview.matchesLegacy,
  currentAppliedSnapshot: _appliedPreview.currentAppliedSnapshot,
  latestAppliedSnapshot: _appliedPreview.latestAppliedSnapshot,
  latestActualizedSnapshot: _appliedPreview.latestActualizedSnapshot,
  calculationAlreadyApplied: true,
  allocationAlreadyPosted: true,
  postingRequiresApply: false,
  canActualizeCalculation: true,
  warnings: const ['organizer_2a_obligation_not_linked'],
);

Future<void> _pumpPanel(
  WidgetTester tester, {
  required Size size,
  required Locale locale,
  SpOrganizerCalculationPreview preview = _preview,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        spOrganizerCalculationPreviewProvider(
          1,
        ).overrideWith((ref) async => preview),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru'), Locale('zh')],
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(8),
            child: SpOrganizerCalculationPanel(purchaseId: 1),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('read-only calculation fits 320 px and separates 2A obligation', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      size: const Size(320, 1000),
      locale: const Locale('ru'),
    );

    expect(find.text('Параметры расчёта'), findsOneWidget);
    expect(find.text('Для себя'), findsOneWidget);
    expect(find.text('Для клиента'), findsOneWidget);
    expect(find.text('Предварительный расчёт по параметрам'), findsOneWidget);
    expect(find.text('Для себя · себестоимость'), findsOneWidget);
    expect(find.text('Для клиента · начисление'), findsOneWidget);
    expect(find.text('Не полный'), findsOneWidget);
    expect(find.textContaining('указать вес'), findsOneWidget);
    expect(find.text('Распределение новых параметров'), findsOneWidget);
    expect(find.text('не начислено'), findsOneWidget);
    expect(find.text('Анна'), findsWidgets);
    expect(find.text('Legacy-баланс и оплаты'), findsOneWidget);
    expect(find.textContaining('только для preview'), findsOneWidget);
    expect(find.text('Явно связанные обязательства перед 2A'), findsOneWidget);
    expect(find.textContaining('Preview не сохранён'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final applyButton = find.widgetWithText(
      FilledButton,
      'Зафиксировать расчёт',
    );
    await tester.ensureVisible(applyButton.first);
    await tester.pumpAndSettle();
    await tester.tap(applyButton.first);
    await tester.tap(applyButton.first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Зафиксировать расчёт?'), findsOneWidget);
    expect(find.textContaining('Начисления, оплаты, позиции'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    await tester.tap(applyButton.first);
    await tester.pumpAndSettle();
    expect(find.text('Зафиксировать расчёт?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    final profileButton = find.byTooltip('Настроить профиль');
    await tester.ensureVisible(profileButton);
    await tester.pumpAndSettle();
    await tester.tap(profileButton);
    await tester.pumpAndSettle();

    expect(find.text('Профиль расчёта'), findsOneWidget);
    expect(find.textContaining('Текущие начисления, оплаты'), findsOneWidget);
    expect(find.text('Для себя'), findsWidgets);
    expect(find.text('Для клиента'), findsWidgets);
    await tester.tap(find.text('Для клиента').last);
    await tester.pumpAndSettle();
    expect(find.text('Заполнить из «Для себя»'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Тариф за 1 кг'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Тариф за 1 кг'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Доставка по стране или городу'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Доставка по стране или городу'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Дополнительные расходы'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Дополнительные расходы'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Комиссия организатора'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Комиссия организатора'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('текущие суммы остаются'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('текущие суммы остаются'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Сохранить для клиента'),
    );
    expect(saveButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'actualized calculation shows breakdown and safe refresh dialog',
    (tester) async {
      await _pumpPanel(
        tester,
        size: const Size(320, 1200),
        locale: const Locale('ru'),
        preview: _appliedPreview,
      );

      expect(
        find.text('Явно связанные обязательства перед 2A'),
        findsOneWidget,
      );
      expect(find.textContaining('2 355'), findsNothing);
      expect(find.textContaining('2355,00 ₽'), findsOneWidget);
      expect(find.text('зафиксировано'), findsOneWidget);
      expect(
        find.textContaining('зафиксировано в неизменяемом снимке'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Полное распределение можно зафиксировать'),
        findsOneWidget,
      );
      final postButton = find.widgetWithText(
        OutlinedButton,
        'Начислить зафиксированное распределение',
      );
      await tester.ensureVisible(postButton.first);
      await tester.pumpAndSettle();
      await tester.tap(postButton.first);
      await tester.pumpAndSettle();

      expect(
        find.text('Начислить зафиксированное распределение?'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Существующие оплаты останутся только в legacy-балансе',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('не уменьшат новый долг'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      final actualizeButton = find.widgetWithText(
        OutlinedButton,
        'Актуализировать связанные суммы 2A',
      );
      await tester.ensureVisible(actualizeButton.first);
      await tester.pumpAndSettle();
      await tester.tap(actualizeButton.first);
      await tester.pumpAndSettle();

      expect(find.text('Актуализировать обязательства 2A?'), findsOneWidget);
      expect(find.textContaining('Долги участников'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('read-only calculation uses Chinese labels at 390 px', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      size: const Size(390, 1000),
      locale: const Locale('zh'),
    );

    expect(find.text('结算参数'), findsOneWidget);
    expect(find.text('按参数预估'), findsOneWidget);
    expect(find.text('未完整'), findsOneWidget);
    expect(find.textContaining('填写重量'), findsOneWidget);
    expect(find.text('新参数分摊'), findsOneWidget);
    expect(find.text('未入账'), findsOneWidget);
    expect(find.text('旧版余额与付款'), findsOneWidget);
    expect(find.text('明确关联的2A应付'), findsOneWidget);
    expect(find.textContaining('预览未保存'), findsOneWidget);
    expect(find.byTooltip('设置结算配置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only calculation fits desktop width', (tester) async {
    await _pumpPanel(
      tester,
      size: const Size(1024, 1200),
      locale: const Locale('ru'),
      preview: _appliedPreview,
    );

    expect(find.text('Параметры расчёта'), findsOneWidget);
    expect(find.text('Предварительный расчёт по параметрам'), findsOneWidget);
    expect(find.text('Явно связанные обязательства перед 2A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('posted allocation is visually separated from legacy balance', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      size: const Size(320, 1300),
      locale: const Locale('ru'),
      preview: _postedPreview,
    );

    expect(find.text('начислено отдельно'), findsOneWidget);
    expect(find.textContaining('Новый ledger начислений'), findsWidgets);
    expect(find.text('Новый долг'), findsWidgets);
    expect(find.text('Legacy-баланс и оплаты'), findsOneWidget);
    expect(
      find.textContaining('Существующие оплаты остаются только'),
      findsOneWidget,
    );
    expect(find.textContaining('Legacy-оплаты не применены'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Распределение начислено отдельно'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
