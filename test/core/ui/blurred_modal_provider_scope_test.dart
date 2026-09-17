import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/ui/blurred_modal_bottom_sheet.dart';

final _clientProvider = Provider<String>((ref) => 'root-client');
final _counterProvider = NotifierProvider<_Counter, int>(_Counter.new);

class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

void main() {
  for (final useRootNavigator in [false, true]) {
    testWidgets(
      'sheet preserves independent caller container with root=$useRootNavigator',
      (tester) async {
        final rootContainer = ProviderContainer();
        final innerContainer = ProviderContainer(
          overrides: [_clientProvider.overrideWithValue('training-client')],
        );
        addTearDown(rootContainer.dispose);
        addTearDown(innerContainer.dispose);
        ProviderContainer? builderContainer;
        String? result;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: rootContainer,
            child: MaterialApp(
              home: UncontrolledProviderScope(
                container: innerContainer,
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: FilledButton(
                        onPressed: () async {
                          result = await showBlurredModalBottomSheet<String>(
                            context: context,
                            useRootNavigator: useRootNavigator,
                            builder: (sheetContext) {
                              builderContainer = ProviderScope.containerOf(
                                sheetContext,
                                listen: false,
                              );
                              return Consumer(
                                builder: (context, ref, _) => SizedBox(
                                  height: 200,
                                  child: Column(
                                    children: [
                                      Text(ref.watch(_clientProvider)),
                                      Text(
                                        'count:${ref.watch(_counterProvider)}',
                                      ),
                                      TextButton(
                                        onPressed: () => ref
                                            .read(_counterProvider.notifier)
                                            .increment(),
                                        child: const Text('Increment'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop('closed'),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(builderContainer, same(innerContainer));
        expect(find.text('training-client'), findsOneWidget);
        await tester.tap(find.text('Increment'));
        await tester.pump();
        expect(find.text('count:1'), findsOneWidget);
        expect(innerContainer.read(_counterProvider), 1);
        expect(rootContainer.read(_counterProvider), 0);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(result, 'closed');
        expect(find.text('Open'), findsOneWidget);
        expect(rootContainer.read(_clientProvider), 'root-client');
        expect(rootContainer.read(_counterProvider), 0);
        expect(innerContainer.read(_counterProvider), 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
