# iOS: обычный Archive и переводчик экрана

Открывать `ios/Runner.xcworkspace`, scheme **Runner**, destination **Any iOS Device** → **Product → Archive**. Archive использует Release; отдельный pilot-скрипт и дополнительные build flags не нужны. Подпись/доступы Apple Developer этим изменением не создаются. После изменения `pubspec.yaml` выполнить обычную подготовку Flutter-зависимостей и проверить фактические version/build в архиве: значения из ранее созданного `Generated.xcconfig` могут быть старыми.

## Настройки по умолчанию

`Flutter/ScreenTranslation.xcconfig` подключён после Generated/Sentry-конфигурации в Debug и Release; Profile наследует Release. Он включает:

- `SCREEN_TRANSLATION_LIVE`, `SCREEN_TRANSLATION_PIP_MEDIA`; без `SCREEN_TRANSLATION_STAGE0` в Release.
- `Runner/ScreenTranslationLive-Info.plist`: background modes `fetch`, `remote-notification`, `screen-capture`, `audio`.
- Dart `SCREEN_TRANSLATION_ENABLED=true`; обе Sentry Replay sample rates равны `0.0`. Crash reporting не отключается.

Эти xcconfig применяются только к iOS. Android и Web не подключают их и сохраняют feature-off; Android-переводчик — отдельная будущая реализация. Native запуск проверяет iOS27; остальные функции приложения сохраняют прежний deployment target. Release не содержит диагностический presenter/тестовый экран.

## Отключение без потери других defines

В Xcode Runner → Build Settings задать User-Defined **`SCREEN_TRANSLATION_MODE = OFF`** для нужной конфигурации. То же самое для автоматизации:

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release SCREEN_TRANSLATION_MODE=OFF archive
```

Один override выбирает обычный `Info.plist`, пустые LIVE/media Swift flags и Dart `SCREEN_TRANSLATION_ENABLED=false`. Остальные `DART_DEFINES` наследуются; не заменять их целиком. Replay намеренно остаётся выключенным и в OFF-режиме. Вернуть `ON` либо удалить override для стандартного поведения. Значения режима — только `ON`/`OFF`.

## Разрешения и данные

Текущий поток — `SCContentSharingPicker` → `SCStream`, не ReplayKit Broadcast Upload Extension. Пользователь разрешает захват в системном окне. Camera/microphone controls скрыты, audio capture выключен. Новые App Group, extension profile, microphone/camera permission или cloud key для переводчика не требуются. Существующие camera/photo permissions нужны другим функциям 2A.

Изображения обрабатываются на iPhone. Для перевода текст передаётся на сервер 2A и в Яндекс; на чужом экране могут оказаться личные данные. Закрытие PiP останавливает сессию. `audio` background mode поддерживает обычный video PiP; аудиобуферов/фиктивного звука нет. [Apple: ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit), [Apple: PiP](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller).

`Runner/PrivacyInfo.xcprivacy` включён в Resources: SystemBootTime, reason `35F9.1` для интервалов/таймеров. После Archive проверить файл в корне `Runner.app`. Это не полная декларация собираемых данных и не замена App Privacy answers.

## Черновик App Review Notes

> Функция доступна на iPhone с iOS27. Войдите предоставленным review-аккаунтом, откройте «Ещё» → «Переводчик». Разрешите захват в системном окне; перейдите в другое приложение с разрешённым тестовым китайским текстом. PiP открывается при выходе из 2A, перевод появляется в отдельном системном окне. Микрофон не используется. Назад/вперёд переключают части экрана; пауза фиксирует снимок. Закройте PiP или нажмите «Остановить» в 2A для завершения. Текст распознаётся локально и отправляется через 2A в Яндекс; изображения не отправляются модели.

Учётные данные заполнять в закрытых полях App Store Connect, не в этом файле. Проверить, что backend доступен и review-аккаунт имеет действующий доступ к переводчику, не истёкший trial. Описание/скриншоты должны отражать iOS27 и реальный PiP, без обещания замены надписей внутри чужих приложений.

## Непройденные публикационные проверки

- Стандартный Archive/Validate после этих изменений и проверка итоговых plist/flags/version/signing; настройка distribution/export отдельно.
- Privacy Policy URL в App Store Connect и ссылка в приложении, актуальные App Privacy answers и описание передачи текста в 2A/Яндекс.
- Сопоставление фактического disclosure/permission flow с Apple 2.5.14 и 5.1.2(i), включая сторонний AI. Отдельный checkbox пользователь исключил; этот документ не утверждает, что ссылка на Terms сама по себе достаточна.
- Полная матрица устройств/ориентаций, длительный тест, end-to-end P50/P95 и качество на согласованном корпусе. Успех сборки и отдельных телефонных проверок не заменяет эти испытания.

[Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): background services использовать по назначению; захват — с разрешением и видимым индикатором; данные/передачу третьим сторонам раскрывать. Эти заметки не гарантируют одобрения App Review. Публикация не выполнялась.
