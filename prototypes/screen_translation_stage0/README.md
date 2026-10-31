# Перевод экрана: диагностический стенд этапа 0 и локальный OCR

Добавлен явно выбираемый локальный OCR с тестовым словарём: [текущий протокол](OCR-PROTOTYPE.md). Реального облачного перевода нет. Непройденная полная приёмка остаётся открытой; ниже сохранён протокол физических проверок capture/PiP.

Статус: диагностика подключена к существующему Flutter Runner в основной рабочей копии `2a-user`. Bundle ID остаётся `com.twoalogistic.user`; используется существующий development-сертификат и профиль. Реального перевода и облачных запросов нет; режим локального OCR/mock включается отдельно. Физический gate остаётся открытым до фактических испытаний.

Пользователь разрешил тестовую установку и `screen-capture`, затем уточнил: использовать то же приложение, сертификат и директорию, без клонов. Отдельная установка больше не используется. Ранее зарегистрированный диагностический App ID остался неиспользованным; отдельный provisioning profile не создан.

Вход в диагностику: Debug либо специальная Profile-сборка с явно заданным `SCREEN_TRANSLATION_STAGE0`, и launch argument `--screen-translation-stage0`. Без аргумента новый UI не открывается. Обычные Release/Profile не компилируют capture/PiP/UI/presenter. Основной `Runner/Info.plist`, entitlements и deployment target iOS 15 не изменены. Для теста используется отдельный plist только через явный build override. Основное решение и ограничения — [ADR-001](ADR-001-ios-feasibility.md).

## Сборка того же приложения

Из корня `2a-user`:

```bash
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Profile -sdk iphoneos \
  -destination id=00008150-000A604C3C44C01C \
  -derivedDataPath ../outputs/2026-10-30-screen-translation-stage0/UserRunnerData \
  SCREEN_TRANSLATION_INFO_PLIST=Runner/ScreenTranslationPiPMedia-Info.plist \
  'SCREEN_TRANSLATION_SWIFT_FLAGS=SCREEN_TRANSLATION_STAGE0 SCREEN_TRANSLATION_PIP_MEDIA' \
  CODE_SIGN_STYLE=Automatic 'CODE_SIGN_IDENTITY=Apple Development' build
```

Команда не содержит `-allowProvisioningUpdates`: профиль и сертификат уже существуют. Установка этой сборки обновляет существующее приложение на устройстве с тем же bundle ID; удаление приложения или очистка его данных не требуется. Сам системный capture начинается только после согласия в диагностическом UI и системного picker.

Profile выбран для самостоятельного запуска без debugger: первая Debug-установка закрывалась, а console подтвердила ограничение FlutterEngine Debug без Flutter tooling/Xcode. Это не был результат испытания ReplayKit/ScreenCaptureKit/PiP — capture до ошибки не запускался.

Физически подтверждены: самостоятельный Profile-запуск, системный запуск capture, видимый обновляемый sample-buffer PiP, переход в Калькулятор на 15–20 секунд с продолжающимся счётчиком, остановка capture при закрытии PiP. Исправления: IOSurface-backed буферы, synchronizer без ожидания preroll и отдельно согласованный media/PiP background mode с playback AVAudioSession. Аудио не создаётся и не воспроизводится, микрофон не запрашивается. Это ограниченная проверка на одном устройстве, а не завершённый этап 0.

Для QA в sandbox Caches записывается один атомарно заменяемый `Library/Caches/ScreenTranslationStage0.json`: код состояния, счётчики, размеры буфера, uptime, supported/possible/active, layerReady, timebase rate/time. Частота — максимум один периодический snapshot/сек плюс события состояния. Кадры, OCR, исходный текст, переводы, токены и provider payload отсутствуют. Диагностика не используется как доказательство фактического отображения PiP.

## Локальная проверка

Из корня `2a-user`:

```bash
python3 prototypes/screen_translation_stage0/generate_project.py
xcodebuild \
  -project prototypes/screen_translation_stage0/ScreenTranslationProbe.xcodeproj \
  -scheme ScreenTranslationProbe -configuration Debug -sdk iphoneos \
  -destination generic/platform=iOS \
  -derivedDataPath ../outputs/2026-10-30-screen-translation-stage0/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
xcrun swiftc \
  prototypes/screen_translation_stage0/SessionGate.swift \
  prototypes/screen_translation_stage0/Tests/SessionGateTests.swift \
  -o ../outputs/2026-10-30-screen-translation-stage0/session-gate-tests
../outputs/2026-10-30-screen-translation-stage0/session-gate-tests
flutter test test/features/garage/garage_translation_test.dart
```

Ранее подготовленный отдельный Xcode-проект остаётся вспомогательным способом проверки нативных исходников без Flutter, а не способом установки. Для его сборки после изменения генератора сначала повторно запустить `generate_project.py`. Он не является второй рабочей копией репозитория. Зависимости не добавлялись. Для установки использовать существующий Runner и команду выше.

Результат 30.10.2026: device arm64 Debug BUILD SUCCEEDED; SessionGate/LatestMailbox проверки прошли; garage translation 3/3. Это не физическая приёмка, UI-тест или подтверждение фонового исполнения.

## Продолжение физического испытания

Используется то же приложение и существующий development profile. Дополнительные `screen-capture` и `audio` background modes включены только явным тестовым plist override. Второй режим согласован пользователем для публичного sample-buffer PiP; аудиопотока и фиктивной тишины нет. `AVAudioSession` активируется только после согласия, завершается при остановке; прежние category/mode/options восстанавливаются, прежнее состояние активности определить нельзя. Тест не совмещать с обычным медиавоспроизведением Runner.

Для проверки самозахвата предусмотрены две отдельные пользовательские QA-кнопки: контрольный ролик без защиты и ролик с `AVSampleBufferDisplayLayer.preventsCapture`. Запись начинается через 4 секунды после фактического старта PiP и длится 10 секунд. Контент — только Калькулятор с вымышленными цифрами. Во время теста перемещать/изменять размер PiP. Захват и PiP завершаются автоматически.

`SCRecordingOutput` в испытанной конфигурации не сообщил о начале записи и оставил 0 байт; успешного ролика этот путь не дал. QA теперь использует отдельный `QAClipWriter` на базе публичного AVAssetWriter: получает те же source buffers на serial video queue после ограничения до 4 выборок/с, пишет только видео H.264, пропускает кадр при backpressure. В обычном режиме writer не создаётся. Очереди кадров и dispatch на каждый исходный кадр нет. Фоновая запись новым writer подтверждена: контрольный ролик 37 кадров / 10,051667 с и защищённый 29 кадров / 9,901667 с, оба 720×1280 H.264 без audio track. Это два коротких испытания, не длительная проверка writer.

В Caches разрешены один завершённый QA-файл и один временный файл с UUID сессии. Завершённый файл публикуется только после terminal writer completion и подтверждённой остановки capture. При ошибке/отмене partial удаляется после завершения; после аварии очищается только собственный файл с ожидаемым UUID-именем. При незавершённой очистке повторный QA блокируется. Sidecar `ScreenTranslationStage0-QA-result.json` содержит ready/status/sessionId/frame count/error code без содержимого. На Mac копировать только ready=true файл соответствующей сессии, затем проверить отсутствие audio track через ffprobe.

Сопоставление raw capture clip и наблюдения пользователя: без защиты текст PiP попадает в source buffers; с `preventsCapture=true` пользователь видит обновляемый текст, а в просмотренных кадрах source вместо него чёрная область. Это предотвращает повторный OCR текста PiP на испытанной конфигурации, но не восстанавливает закрытую им область приложения. Дополнительный ролик 38 кадров / 10,118333 с подтверждает перемещение защищённого окна, изменение его размера и уход за край; пользователь подтвердил сохранение работы при повороте. Все десять просмотренных кадров не содержат текста PiP. Ландшафтный захват и все варианты orientation отдельно этим роликом не доказаны. Не включать OCR/LLM до проверки самозахвата, устойчивости и жизненного цикла. Для Taobao/1688 нужны разрешённые обезличенные товарные страницы; переписку, адреса и платежи не записывать.

## Матрица устройств и gate

| Устройство / версия | Доступ | Установка / запуск | Background + PiP | 15 минут / память / батарея |
|---|---|---|---|---|
| iPhone 17 Pro Max / iOS 27.0.1 (24A446) | paired, Developer Mode | Profile установлен и запускается | подтверждено пользователем в Калькуляторе 15–20 с | не измерено |
| Физический iPhone / iOS 15–26 | не предоставлен | не выполнено | ReplayKit-путь не реализован | не измерено |
| Simulator | доступен | не использован для доказательства | не принимается как доказательство | не принимается |

| Испытание | Статус | Что должно быть зафиксировано |
|---|---|---|
| Системный запуск, cancel, отказ, restricted capture | NOT RUN | реальный picker и понятное завершение |
| Собственный тестовый текст в sample-buffer PiP | PASS, пользователь | PiP появился и обновляется |
| Host → Калькулятор → возврат | PARTIAL PASS | счётчик меняется в фоне, capture/PiP принадлежат host |
| Scroll, баннеры, 100 смен экранов, orientation | NOT RUN | актуальность и ограниченная очередь |
| PiP move/resize/stash/restore, самозахват | PARTIAL PASS | защищённый PiP перемещается/меняет размер/уходит за край без текста в просмотренных source frames; все orientation отдельно не доказаны |
| Закрытие PiP крестиком | PASS, пользователь | захват остановился; системная остановка/пауза отдельно не проверены |
| Lock/unlock, системная остановка | PASS, пользователь | оба прекращают сессию без самостоятельного возобновления; final metadata captureStopState=stopped |
| Interruption, host termination | NOT RUN | отдельная полная проверка ещё нужна |
| Memory pressure, 15 минут, нагрев/батарея | DEFERRED | 15-минутный прогон отложен по просьбе пользователя; короткий фоновой sample не заменяет его |
| Потеря сети | NOT APPLICABLE для стенда | сетевого кода нет; обязательно на будущем переводчике |
| RU/KZ/BY network, DeepSeek latency/quality/cost | DEFERRED | только после iOS gate и отдельного бюджета |

Endpoint, API schema v1, translation cache, пользовательский feature flag, fallback model, реальный provider и отчёт его качества пока отсутствуют. После коротких физических проверок и отдельной команды пользователя подготовлен локальный OCR/mock, описанный в OCR-PROTOTYPE.md; это не закрывает оставшуюся эксплуатационную матрицу.

## Остановка и откат

В стенде: кнопка «Остановить», системная остановка screen capture, закрытие/пауза PiP. Lock/memory notifications также инвалидируют сессию. Диагностика подключена к тому же Runner через условную компиляцию и launch argument. Для возврата собрать обычный Runner без тестовых флагов и plist override; удалить приложение или его данные не требуется. Release-конфигурация и основной plist не изменены.

Если gate не проходит, зависимую реализацию остановить. Ограниченный следующий вариант — отдельный скриншот/изображение или Share с локальным OCR и явным переводом; его нельзя обозначать live-режимом.

Остановка усилена после code review: обычный capture сохраняет владельца до подтверждения и выполняет максимум две автоматические попытки. При неудаче показывается ошибка, новый захват блокируется; явный новый запуск повторяет ограниченную остановку старого. QA watchdog отменяет зависшую финализацию writer, включая отмену после начала finishWriting. Готовый файл по-прежнему требует terminal writer + stop acknowledgement. Отказы API проверены статически; принудительная fault injection на устройстве не выполнена.
