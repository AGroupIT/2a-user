# Загрузка AAB в RuStore

Собрать `rustore` flavor с текущей версией из `pubspec.yaml`. Android-переводчик отсутствует; не включать iOS-only флаг для Android.

Загрузчик использует актуальный `public-api-m.rustore.ru`. Ключ остаётся в `~/.rustore/private_key_user.pem`; token хранится только в памяти/stdin. Создаётся один новый MANUAL draft. Чужие черновики не удаляются, submit/moderation/публикация не вызываются. При существующем черновике требуется проверить его и явно продолжить только собственный report через `--resume-report`.

Пример из корня `2a-user` (подставить проверенный SHA256 и актуальные версии):

```sh
python3 tools/upload_rustore_aab.py \
  --aab build/app/outputs/bundle/rustoreRelease/app-rustore-release.aab \
  --version-name 1.2.48 --version-code 79 \
  --expected-sha256 '<проверенный SHA256>' \
  --whats-new-file /absolute/path/release-notes.txt \
  --report /absolute/path/rustore-upload-report.json
```

Перед облачным вызовом проверяются package/version внутри AAB и SHA256. Повторы mutations автоматически не выполняются; сначала проверить результат через read-only API. Успешный upload не означает отправку на модерацию. RuStore может не показывать AAB в консоли до отправки draft на модерацию.

`certs/rustore-request-ca.pem` — публичные root/intermediate сертификаты Минцифры из официальных ссылок Госуслуг, приведённых RuStore. Они применяются только к HTTPS-запросам этого загрузчика. Системные trust stores, браузеры и приложение не меняются; TLS chain/hostname validation включена.

Источники: [миграция API и сертификатов](https://www.rustore.ru/help/developers/monetization/payment-callback/Preparing-the-server-for-RuStore%20API), [AAB upload](https://www.rustore.ru/help/work-with-rustore-api/api-upload-publication-app/apk-file-upload/file-upload-aab).

Общий `build_web.sh` тоже переведён на новый API и этот per-request CA bundle. Он сохраняет прежний интерактивный workflow, включая отправку на модерацию. Для отдельной загрузки без удаления чужих черновиков использовать приведённый Python helper.
