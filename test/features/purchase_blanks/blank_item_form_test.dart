import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:twoalogisticcabineuser/src/features/purchase_blanks/presentation/widgets/blank_item_form.dart';

void main() {
  testWidgets('photo picker is serialized and unlocks after completion', (
    tester,
  ) async {
    final firstResult = Completer<List<XFile>>();
    var calls = 0;
    await tester.pumpWidget(
      _FormHost(
        photoPicker: () {
          calls++;
          if (calls == 1) return firstResult.future;
          return Future.value(const []);
        },
      ),
    );

    final addPhotos = find.byKey(const Key('blank_item_add_photos'));
    await tester.tap(addPhotos);
    await tester.pump();
    await tester.tap(addPhotos);
    await tester.pump();
    expect(calls, 1);

    firstResult.complete(const []);
    await tester.pump();
    await tester.tap(addPhotos);
    await tester.pump();

    expect(calls, 2);
  });

  testWidgets('photo picker unlocks after an error without hiding it', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _FormHost(
        photoPicker: () {
          calls++;
          if (calls == 1) {
            return Future<List<XFile>>.error(
              PlatformException(code: 'already_active'),
            );
          }
          return Future.value(const []);
        },
      ),
    );

    final addPhotos = find.byKey(const Key('blank_item_add_photos'));
    final dynamic callback = tester.widget<InkWell>(addPhotos).onTap;
    final Future<void> firstAttempt = callback() as Future<void>;
    await expectLater(firstAttempt, throwsA(isA<PlatformException>()));
    await tester.pump();

    await tester.tap(addPhotos);
    await tester.pump();
    expect(calls, 2);
  });
}

class _FormHost extends StatelessWidget {
  const _FormHost({required this.photoPicker});

  final BlankItemPhotoPicker photoPicker;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlankItemForm(
            photoPicker: photoPicker,
            onSave:
                ({
                  required productName,
                  required productUrl,
                  characteristics,
                  required quantity,
                  required unitPrice,
                  newPhotos,
                  newPhotoNames,
                }) async {},
          ),
        ),
      ),
    );
  }
}
