import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/ui/packaging_removal_text.dart';
import 'package:twoalogisticcabineuser/src/features/assemblies/domain/assembly_item.dart';
import 'package:twoalogisticcabineuser/src/features/calculator/domain/assembly_cost_calculation.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/assemblies_provider.dart';

class _MockApiClient extends Mock implements ApiClient {}

AssemblyCostResult? _calculate(
  PackagingRemovalOption option, {
  bool supportsTargets = true,
  double? partialPrice = 3,
}) => calculateAssemblyCost(
  AssemblyCostInput(
    tariff: CalculatorTariff(
      id: 1,
      name: 'Tariff',
      baseCost: 5,
      paidPhotoReport: false,
      packagingRemovalTransportPrice: partialPrice,
      packagingRemovalAllPrice: 2,
      supportsPackagingRemovalTargets: supportsTargets,
    ),
    photoCoefficients: const [],
    selectedPackagings: const [
      CalculatorPackaging(id: 1, name: 'Box', baseCost: 1),
    ],
    weightKg: 10,
    volumeM3: 0.1,
    places: 1,
    tracksTotal: 1,
    tracksWithPhoto: 0,
    unloadingCostUsd: 0,
    packagingRemoval: option,
  ),
);

void main() {
  test('new choices encode base plus target and round trip exactly', () {
    for (final (option, target) in [
      (PackagingRemovalOption.boxOnly, 'box'),
      (PackagingRemovalOption.bagOnly, 'bag'),
    ]) {
      final payload = option.toApi(supportsTargets: true);
      expect(payload, {
        'packagingRemoval': 'transport_only',
        'packagingRemovalTarget': target,
      });
      expect(
        PackagingRemovalOption.fromApi(
          payload['packagingRemoval'],
          payload['packagingRemovalTarget'],
        ),
        option,
      );
    }
  });

  test('legacy partial selection never becomes a box or bag selection', () {
    expect(
      PackagingRemovalOption.fromApi('transport_only', null),
      PackagingRemovalOption.transportOnly,
    );
    expect(PackagingRemovalOption.transportOnly.toApi(supportsTargets: true), {
      'packagingRemoval': 'transport_only',
      'packagingRemovalTarget': null,
    });
    expect(PackagingRemovalOption.available(supportsTargets: true), [
      PackagingRemovalOption.none,
      PackagingRemovalOption.boxOnly,
      PackagingRemovalOption.bagOnly,
      PackagingRemovalOption.all,
    ]);
    expect(
      PackagingRemovalOption.available(
        supportsTargets: true,
        current: PackagingRemovalOption.transportOnly,
      ),
      contains(PackagingRemovalOption.transportOnly),
    );
  });

  test('old backend retains legacy choices and rejects targeted payloads', () {
    expect(PackagingRemovalOption.available(supportsTargets: false), [
      PackagingRemovalOption.none,
      PackagingRemovalOption.transportOnly,
      PackagingRemovalOption.all,
    ]);
    for (final option in PackagingRemovalOption.values) {
      if (option.target != null) {
        expect(
          () => option.toApi(supportsTargets: false),
          throwsUnsupportedError,
        );
      } else {
        expect(option.toApi(supportsTargets: false), {
          'packagingRemoval': option.apiValue,
        });
        expect(
          option.toApi(supportsTargets: true)['packagingRemovalTarget'],
          isNull,
        );
      }
    }
  });

  test('both assembly models preserve base, target and capability', () {
    for (final target in [null, 'box', 'bag']) {
      final json = <String, dynamic>{
        'id': 1,
        'packagingRemoval': 'transport_only',
        'packagingRemovalTarget': target,
        'supportsPackagingRemovalTargets': true,
      };
      final assembly = Assembly.fromJson(json);
      final item = AssemblyItem.fromJson(json);
      expect(assembly.packagingRemoval, 'transport_only');
      expect(item.packagingRemoval, 'transport_only');
      expect(assembly.packagingRemovalTarget, target);
      expect(item.packagingRemovalTarget, target);
      expect(assembly.supportsPackagingRemovalTargets, isTrue);
      expect(item.supportsPackagingRemovalTargets, isTrue);
    }
    final old = <String, dynamic>{
      'id': 1,
      'packagingRemoval': 'transport_only',
    };
    expect(Assembly.fromJson(old).packagingRemovalTarget, isNull);
    expect(AssemblyItem.fromJson(old).packagingRemovalTarget, isNull);
    expect(Assembly.fromJson(old).supportsPackagingRemovalTargets, isFalse);
    expect(AssemblyItem.fromJson(old).supportsPackagingRemovalTargets, isFalse);
  });

  test('tariff capability requires explicit true in both consumers', () {
    for (final flag in [null, false, 'true', true]) {
      final json = <String, dynamic>{
        'id': 1,
        if (flag != null) 'supportsPackagingRemovalTargets': flag,
      };
      expect(
        Tariff.fromJson(json).supportsPackagingRemovalTargets,
        flag == true,
      );
      expect(
        CalculatorTariff.fromJson(json).supportsPackagingRemovalTargets,
        flag == true,
      );
    }
  });

  for (final option in PackagingRemovalOption.values) {
    test(
      'create API preserves ${option.name} exactly on capable backend',
      () async {
        final api = _MockApiClient();
        when(
          () => api.post('/assemblies', data: any(named: 'data')),
        ).thenAnswer((invocation) async {
          final body = invocation.namedArguments[#data] as Map<String, dynamic>;
          return Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/assemblies'),
            statusCode: 201,
            data: {...body, 'id': 9, 'supportsPackagingRemovalTargets': true},
          );
        });
        final container = ProviderContainer(
          overrides: [apiClientProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);
        final result = await container
            .read(assembliesApiServiceProvider)
            .createAssembly(
              clientId: 1,
              packagingRemoval: option.apiValue,
              packagingRemovalTarget: option.target,
              supportsPackagingRemovalTargets: true,
            );
        expect(result.isSuccess, isTrue);
        final body =
            verify(
                  () =>
                      api.post('/assemblies', data: captureAny(named: 'data')),
                ).captured.single
                as Map;
        expect(body['packagingRemoval'], option.apiValue);
        expect(body.containsKey('packagingRemovalTarget'), isTrue);
        expect(body['packagingRemovalTarget'], option.target);
        expect(result.assembly!.packagingRemovalTarget, option.target);
      },
    );
  }

  for (final option in [
    PackagingRemovalOption.boxOnly,
    PackagingRemovalOption.bagOnly,
  ]) {
    test(
      'create API blocks ${option.name} before sending to old backend',
      () async {
        final api = _MockApiClient();
        final container = ProviderContainer(
          overrides: [apiClientProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);
        final result = await container
            .read(assembliesApiServiceProvider)
            .createAssembly(
              clientId: 1,
              packagingRemoval: option.apiValue,
              packagingRemovalTarget: option.target,
            );
        expect(result.errorCode, packagingRemovalTargetsUnsupportedCode);
        verifyZeroInteractions(api);
      },
    );
  }

  test('create API sends unchanged legacy payload on old backend', () async {
    final api = _MockApiClient();
    when(() => api.post('/assemblies', data: any(named: 'data'))).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/assemblies'),
        statusCode: 201,
        data: {'id': 1, 'packagingRemoval': 'transport_only'},
      ),
    );
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final result = await container
        .read(assembliesApiServiceProvider)
        .createAssembly(clientId: 1, packagingRemoval: 'transport_only');
    final body =
        verify(
              () => api.post('/assemblies', data: captureAny(named: 'data')),
            ).captured.single
            as Map;
    expect(body['packagingRemoval'], 'transport_only');
    expect(body.containsKey('packagingRemovalTarget'), isFalse);
    expect(result.assembly!.packagingRemovalTarget, isNull);
  });

  test('box, bag and legacy partial use the exact same existing rate', () {
    for (final option in [
      PackagingRemovalOption.boxOnly,
      PackagingRemovalOption.bagOnly,
      PackagingRemovalOption.transportOnly,
    ]) {
      final result = _calculate(option)!;
      expect(result.clientPrice, 3);
      expect(result.shippingCost, 30);
      expect(result.total, 31);
      expect(_calculate(option, partialPrice: null)!.clientPrice, 5);
      expect(_calculate(option, partialPrice: 0)!.clientPrice, 5);
    }
    expect(_calculate(PackagingRemovalOption.all)!.clientPrice, 2);
  });

  test(
    'calculator refuses targeted selection until capability is advertised',
    () {
      expect(
        _calculate(PackagingRemovalOption.boxOnly, supportsTargets: false),
        isNull,
      );
      expect(
        _calculate(PackagingRemovalOption.bagOnly, supportsTargets: false),
        isNull,
      );
      expect(
        _calculate(
          PackagingRemovalOption.transportOnly,
          supportsTargets: false,
        )!.clientPrice,
        3,
      );
    },
  );

  for (final locale in ['ru', 'zh']) {
    testWidgets('shared choice labels are exact in $locale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('ru'), Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  for (final option in [
                    PackagingRemovalOption.boxOnly,
                    PackagingRemovalOption.bagOnly,
                    PackagingRemovalOption.all,
                  ])
                    Text(packagingRemovalLabel(context, option)),
                  Text(packagingRemovalTargetsUnavailableText(context)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label
          in locale == 'ru'
              ? [
                  'Удалить коробку',
                  'Снять упаковку с сумки',
                  'Удалить всю упаковку',
                ]
              : ['拆除盒子包装', '拆除袋子包装', '拆除全部包装']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.textContaining(locale == 'ru' ? 'после обновления' : '服务更新后'),
        findsOneWidget,
      );
    });
  }
}
