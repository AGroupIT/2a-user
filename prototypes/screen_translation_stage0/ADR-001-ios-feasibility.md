# ADR-001: этап 0 перевода экрана на iPhone

Дата: 30.10.2026. Статус: частичная физическая проверка на одном iPhone. Обновляемый PiP и capture работают поверх Калькулятора; закрытие PiP останавливает capture. Контрольный и защищённый видеоролики проверены. Полный gate этапа 0 остаётся открытым; OCR/LLM не подключаются.

## Решение и конфигурация

Диагностика подключена к существующему Flutter Runner в основной рабочей копии 2a-user. Используются bundle ID com.twoalogistic.user и существующие team/certificate/profile. Установка обновляет то же приложение; удаление приложения, очистка пользовательских данных, клон или worktree не нужны.

Для доступного iOS 27 устройства выбран эксперимент: ScreenCaptureKit в host-процессе и обычный sample-buffer PiP. Video-call ContentSource, private API, фиктивное аудио и скрытый keepalive не используются. Это проверенный в ограниченном сценарии кандидат, а не архитектура для всех iPhone.

Физическая сборка — Profile со следующими явными overrides:

    SCREEN_TRANSLATION_INFO_PLIST=Runner/ScreenTranslationPiPMedia-Info.plist
    SCREEN_TRANSLATION_SWIFT_FLAGS=SCREEN_TRANSLATION_STAGE0 SCREEN_TRANSLATION_PIP_MEDIA

Дополнительный вход — launch argument --screen-translation-stage0. Без него диагностический UI не открывается. Пользователь отдельно даёт согласие в UI и запускает системный picker. Обычные Release/Profile без overrides не компилируют capture/PiP/UI/presenter. Native guards используют DEBUG || SCREEN_TRANSLATION_STAGE0, классы защищены availability iOS 27.

Основной Runner/Info.plist, entitlements и deployment target iOS 15.0 сохранены. Согласованный тестовый plist добавляет screen-capture, audio и landscape только для испытания. В артефакте Runner подтверждена weak linkage ScreenCaptureKit; это не заменяет физический запуск на iOS 15–26. Команда сборки — в [README](README.md), без автоматического обновления provisioning.

Первый самостоятельный Debug-запуск завершался до capture: console подтвердила ограничение FlutterEngine Debug без Flutter tooling/Xcode. Поэтому используется Profile без debugger. Flutter запускается в обычном Runner; диагностический экран, capture и PiP реализованы нативно, без предположения о бессрочной работе Dart в фоне.

Standalone Xcode-проект сохранён только как вспомогательный unsigned build/typecheck нативных исходников, а не второй способ установки. Ранее зарегистрированный диагностический App ID не используется, отдельный профиль для него не создан. Новых сертификатов, ключей, App Group или extension для текущего пути нет.

## База и устройство

| Параметр | Значение |
|---|---|
| Основная рабочая копия | /Volumes/T7/2a-logistic/2a-user |
| Ветка | feature/screen-translation-stage0-20261030 |
| Base commit | c30d85371193c533d38482ab5b02d4522461a190 |
| Локальный origin/main при старте | 035fdad32edcb84917816960cf334574d5ae463f; не доказательство актуального remote HEAD |
| Backend HEAD при старте | 255d9d43638a7108b3162955cbaf8f3266884997; feat/warehouse-isolation-20261001 |
| Xcode / SDK | Xcode 27.1 (27A9275), iPhoneOS SDK 27.1 |
| Основной Runner | iOS 15.0 deployment target, com.twoalogistic.user, team 8DYZBYA8L9 |
| Устройство | iPhone 17 Pro Max, iOS 27.0.1 (24A446), paired, Developer Mode |
| Установка | Profile, прежний development-сертификат/профиль, обновление существующего приложения |

Обе рабочие копии при старте были dirty; изменения пользователя сохранены, checkout на main не выполнялся. Backend этой задачей не изменялся. Commit/push/deploy и публикация в App Store не выполнялись.

## Существующий перевод сохранён

В ios/Runner/AppDelegate.swift сохранён handler com.twoalogistic.user/text_recognition: recognizeText, Vision accurate, zh-Hans/en-US, путь к изображению, строки без bbox. Добавлен условный вход в диагностический presenter; OCR handler не менялся.

lib/src/features/garage/presentation/garage_translated_text.dart сохраняет /translate, direction zh-ru, memory cache, дедупликацию, последовательную очередь и проверку версии ответа виджета. Старый переводчик не менялся; garage translation regression tests прошли 3/3.

В backend app/api/translate/route.ts и lib/yandex-translation.ts уже были dirty-изменения пользователя, включая Qwen и retries/timeouts. Описание main в ТЗ не описывает эти локальные изменения или production. Модель production БД в рамках этапа 0 не проверялась.

## Проверенные SDK-факты

Заголовки проверены в /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk.

| API | Заголовок / подтверждение |
|---|---|
| RPBroadcastSampleHandler / RPBroadcastHandler | ReplayKit/RPBroadcastExtension.h: deprecated iOS 27, No longer supported |
| RPSampleBufferType | тот же: deprecated iOS 27, замена SCStreamOutputType |
| RPSystemBroadcastPickerView | ReplayKit/RPBroadcast.h: deprecated iOS 27, замена SCContentSharingPicker |
| SCContentSharingPicker / SCStream | ScreenCaptureKit headers: доступны с iOS 27 |
| Обычный sample-buffer PiP ContentSource | AVKit/AVPictureInPictureController_AVSampleBufferDisplayLayerSupport.h: доступен с iOS 15, без найденной deprecation |
| Video-call ContentSource | AVKit/AVPictureInPictureController_VideoCallSupport.h: только активный видеозвонок; не используется |
| Renderer / writer receivers | AVFoundation headers/Swift interface: используются современные receiver API |
| IOSurface-backed CVPixelBuffer | AVSampleBufferDisplayLayer.h:107–109: необходим для данного display path; реализован kCVPixelBufferIOSurfacePropertiesKey |
| Window/app exclusions SCContentFilter | соответствующие macOS методы в SCStream.h недоступны на iOS |
| preventsCapture | AVSampleBufferDisplayLayer.h:188–192: public iOS 13+, без deprecation; защита image data слоя, без отдельной гарантии переноса через PiP |

Для iOS 15–26 остаётся отдельный кандидат ReplayKit + Broadcast Upload Extension. Он не реализован и не принят: нужны соответствующее устройство, согласованные signing/extension/App Group и проверка процессов. Депрекация iOS 27 не доказывает отказ старых версий.

## Владельцы, очереди и lifecycle

Host-процесс Runner владеет picker, SCStream, serial video queue, состоянием сессии, PiP controller и renderer. Broadcast Extension, App Group, shared storage и IPC для этого кандидата не нужны и не создавались. У native pipeline нет сетевого кода; Runner сохраняет свои обычные функции.

После согласия пользователь выбирает full-display capture. Microphone/camera controls скрыты; фильтр с включённой камерой/микрофоном отклоняется. capturesAudio=false, audio/microphone outputs не регистрируются, неожиданные non-screen buffers сразу отбрасываются. Нового доступа к Photos, camera или микрофону нет.

Для публичного ordinary PiP пользователь отдельно согласовал media-конфигурацию: playback/moviePlayback/mixWithOthers, active AVAudioSession и audio background capability. Audio samples, player и генератор тишины не создаются. Lease активируется после согласия и завершается при stop/deinit/interruption; прежние category/mode/options восстанавливаются, ошибки cleanup записываются domain/code. Прежнее состояние активности общей audio session определить нельзя: тест не совмещается с media playback Runner.

Source ограничивает обработку четырьмя выборками в секунду по monotonic uptime. Mailbox хранит одно последнее событие и максимум одну доставку на Main. На Main передаются только count/размеры. PiP рисуется собственными IOSurface-backed пикселями; synchronizer не ждёт preroll, renderer удерживает один async enqueue и один latest pending frame.

Каждый запуск получает новый token и отдельный PiP owner. Поздние capture/PiP callbacks не меняют новую сессию. Stop инвалидирует token, отменяет deadlines и pending работу. Закрытие/пауза PiP, ошибки, lock/memory notifications и media interruption ведут к stop; автоматического restart нет. Полная системная матрица этих путей ещё не принята.

Есть ограниченные отменяемые таймеры readiness/QA countdown/duration/cleanup. Synthetic PiP обновляется от video callbacks, а не автономного таймера. Enqueue сам по себе не доказывает display; ниже указаны отдельные физические доказательства.

## Данные и согласованная QA-запись

По умолчанию screen frames не сохраняются, OCR/перевода нет. В Caches атомарно заменяется ScreenTranslationStage0.json: состояния/sessionId, uptime, counters, размеры, PiP readiness/timebase, PID, app/thermal state, собственный resident/physical footprint и cleanup error codes. Изображений, текста, токенов/provider payload в metadata нет.

Запись включается отдельно на iPhone и по умолчанию выключена. Разрешён только Калькулятор с вымышленными цифрами. После фактического PiP start — четыре секунды countdown, затем десять секунд raw capture QA, после чего capture/PiP завершаются. Отдельно выбираются baseline и preventsCapture; защита по умолчанию выключена. Передача разрешена только на локальный Mac пользователя, без сервера/облака.

SCRecordingOutput в испытанной конфигурации не сообщил о старте и дал ноль байт; успешного ролика этот путь не дал и заменён. QAClipWriter использует AVAssetWriter/H.264 с единственным video input: те же raw source buffers, serial video queue, не более 4 выборок/с, appendImmediately с drop при backpressure. Размер/формат берутся из buffer, первый успешный PTS сдвигается в ноль. Нет очереди raw frames или dispatch на каждый исходный кадр; finishWriting/cancelWriting дают единственный terminal result.

Хранение ограничено одним готовым ScreenTranslationStage0-QA.mp4 и одним текущим UUID.partial.mp4. Готовый файл публикуется только после terminal writer success и остановки capture. Cancel/failure partial удаляется после cleanup. Orphan cleanup затрагивает только собственный UUID-шаблон; незавершённая очистка блокирует новый QA. Sidecar ScreenTranslationStage0-QA-result.json содержит ready/status/sessionId/число frames/error code без screen content. Для передачи принимается только ready=true файл нужной сессии с независимой проверкой ffprobe.

## Физические результаты

Пользователь подтвердил PiP поверх Калькулятора с продолжающимся счётчиком в течение 15–20 секунд и остановку capture при закрытии PiP. Затем выполнены baseline и protected QA в том же Runner. Артефакты находятся в outputs/2026-10-30-screen-translation-stage0/ родительского workspace.

| Набор | Подтверждённый результат |
|---|---|
| Baseline session | 3558A734-DDA6-4C54-A888-30FFEFAB2B21 |
| qa-assetwriter-result.json | ready=true, finished, 37 frames, recordingFinalized=true, stopAcknowledged=true, streamCapturing=false |
| qa-baseline-assetwriter.mp4, ffprobe | H.264, 720×1280, 37 frames, 10.051667 с, один video stream, audio track отсутствует |
| qa-baseline-contact.png | В raw source видны Калькулятор и собственные меняющиеся надписи PiP |
| Protected session | C382D993-09CD-49AA-8B6C-BE1744714993 |
| qa-protected-result.json | ready=true, finished, 29 frames, recordingFinalized=true, stopAcknowledged=true, streamCapturing=false |
| qa-protected-assetwriter.mp4, ffprobe | H.264, 720×1280, 29 frames, 9.901667 с, один video stream, audio track отсутствует |
| qa-protected-contact.png | В десяти выбранных кадрах raw source вместо PiP text виден чёрный прямоугольник |
| Внешнее наблюдение protected | Пользователь подтвердил, что видимый ему PiP продолжал обновляться |

Matched metadata подтверждает preventsCapture=false/true соответственно, appState=2, PID 15075 и IOSurface-backed buffers. Перед stop layerReady=true, possible=true, active=true, timebase rate=1. После stop layerReady может стать false из-за flush, а active — кратковременно оставаться true до окончания анимации; readiness оценивается по pre-stop metadata и наблюдению.

Baseline snapshot: residentBytes=218660864, footprintBytes=171116624, thermalState=0; protected: residentBytes=229965824, footprintBytes=179144808, thermalState=0. Это отдельные снимки, не исследование утечки или memory limit. Source callback counts и количество MP4 frames не подменяют capture/processing FPS, батарею или 15-минутный тест.

**Вывод о самозахвате ограничен проверенным сценарием.** Автоматического исключения PiP без защиты нет. preventsCapture=true в этой конфигурации убирает собственные PiP pixels из raw capture, сохраняя видимый пользователю PiP. Это квалифицированный положительный результат для предотвращения OCR собственных надписей на данном устройстве. Он не восстанавливает китайский контент под чёрной областью и не предоставляет её координаты. В contact sheets PiP расположен одинаково: исчерпывающая проверка перемещения/resize/stash/orientation не доказана. Обобщать результат на все iPhone, ReplayKit или версии iOS нельзя.

Первоначальные verification.json и verification-runner-profile.json — ранние снимки, их строки «не установлено/ожидает испытания» не описывают текущие результаты. Эти baseline/protected артефакты являются более свежим источником состояния.

## Открытый gate

| Проверка | Состояние |
|---|---|
| Profile launch, user picker, собственный обновляемый PiP | подтверждено на одном iPhone |
| Host → Калькулятор, 15–20 с, закрытие PiP | подтверждено пользователем |
| Video-only baseline/protected QA и финализация | подтверждено двумя MP4 и matching sidecars |
| Self-capture control в фиксированном положении | квалифицированный pass: чёрная область вместо PiP pixels |
| Move/resize/stash/restore и ориентации | полный прогон не доказан; обязателен до принятия механизма |
| Cancel/отказ/restricted/пустой кадр, lock/interruption/host termination/cleanup | полная матрица не принята; отдельные попытки её не заменяют |
| Taobao/1688, scroll/баннеры, 100 смен экранов | не выполнено; нужны разрешённые обезличенные товарные страницы |
| 15 минут на целевых iPhone, memory pressure/очереди/нагрев/батарея | не измерено в требуемом объёме |
| iOS 15–26 и другие устройства | не проверено |
| Network loss нового pipeline | неприменимо к стенду без сети; обязательно будущему переводчику |
| RU/KZ/BY маршруты, DeepSeek latency/quality/cost | отложено до iOS gate и согласованного бюджета |

Короткий Calculator baseline не завершает этап 0 и не доказывает App Store acceptance. До полной проверки самозахвата и lifecycle не подключать OCR/LLM и зависимую продуктовую реализацию. Если устойчивый публичный путь не подтверждается, live-ветка останавливается; ограниченный вариант — отдельное изображение/скриншот или Share, явно без live-обещания.

После gate можно проектировать Flutter coordinator, OCR bbox и bounded translation endpoint. DeepSeek/Yandex URI/API/reasoning, качество, задержка, стоимость, production model и RU/KZ/BY routes пока не проверены. Платных вызовов, новых IAM/секретов, backend endpoint, изменения старого /translate, production deploy или публикации нет. Облачный эксперимент требует отдельного бюджета; выпуск — отдельного одобрения.

## Остановка и откат

Остановить probe можно кнопкой, возвратом в 2A User, закрытием/паузой PiP и системной остановкой capture. Нативные error/lock/memory/interruption paths и QA cleanup проверяются полной физической матрицей. Скрытого возобновления нет.

Откат — обычный Runner без диагностических Swift flags и plist override. Основной plist и Release-конфигурация сохраняют прежнее поведение; удаление приложения или пользовательских данных не требуется. Согласованные QA-файлы передаются/очищаются отдельно.

## Источники

- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [Capturing screen content on iOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios) — iOS 27; дополнительные camera/audio/Photos функции образца не копируются автоматически.
- [ReplayKit](https://developer.apple.com/documentation/replaykit)
- [RPBroadcastSampleHandler](https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler)
- [Configuring background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes)
- [Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)
- [PiP ContentSource](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller/contentsource-swift.class)
- [preventsCapture](https://developer.apple.com/documentation/avfoundation/avsamplebufferdisplaylayer/preventscapture)
- [App extension lifecycle](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — 2.5.1/2.5.4/2.5.14 и 5.1.1/5.1.2 перед выпуском; review не гарантируется.

SDK/docs обосновывают эксперимент; физическую работоспособность подтверждают только конкретное устройство, воспроизводимый сценарий и его артефакты.


## Дополнение: короткая проверка движения и остановки

30.10.2026, тот же iPhone/host/Profile. `qa-move-rotate-result.json` и диагностика относятся к сессии `B69DA1B3-1AF6-4634-BB5B-EB555D791FE5`: 38 frames, 10.118333 s, 720×1280 H.264, audio отсутствует, `preventsCapture=true`, capture stop acknowledged, media cleanup errors отсутствуют. Контактный лист из десяти кадров показывает перемещение/размер/уход за край защищённого окна; текст PiP в этих кадрах отсутствует. Пользователь подтвердил продолжающуюся работу при повороте; отдельного ландшафтного кадра в просмотренной выборке нет.

Пользователь отдельно подтвердил завершение при lock/unlock и системной остановке через индикатор, без автоматического возобновления. Последняя диагностика `lifecycle-final.json`: running=false, state=session_stopped, captureStopState=stopped, qaState=off, mediaCleanupErrors=[]. Поле PiP.active в нем является синхронным snapshot сразу после запроса асинхронной остановки PiP, поэтому оно не доказывает конечное состояние системного окна; факт закрытия подтверждён пользователем.

15-минутный прогон отложен по просьбе пользователя. Успел собраться один дополнительный фоновой sample примерно через 40 с: PiP активен, тот же session/PID, footprint около170 MiB, thermalState=0. Это не доказывает отсутствие утечки и не заменяет длительную приёмку. Interruption, memory pressure, host termination, полноценная целевая прокрутка Taobao/1688 и старые iOS остаются открыты.

После статического review усилено завершение: обычный stop удерживает владельца до подтверждения, ограничивает автоматические попытки и разрешает явный retry при следующем запуске; QA timeout отменяет writer даже после начала финализации. При продолжающемся capture один handle сохраняется, повторный capture блокируется, новый явный запуск повторяет ограниченный stop. Ошибочные callbacks/зависания SDK проверены статически, fault injection не выполнена. Native typecheck с warnings-as-errors, portable SessionGate/LatestMailbox tests и Profile build прошли.
