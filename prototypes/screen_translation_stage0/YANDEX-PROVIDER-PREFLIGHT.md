# Read-only preflight Яндекс, 30.10.2026

Платных запросов не было. Проверены публичные документы, не реальный доступ аккаунта, настройки production или модель в БД.

- Каталог содержит DeepSeek V4.1 Flash: `gpt://<folder_id>/deepseek-v4.1-flash`. Для неё заявлены OpenAI-compatible API; старый Foundation Models completion adapter не считать совместимым. [Модели](https://aistudio.yandex.ru/ru/docs/ai-studio/concepts/generation/models).
- Предлагаемый новый adapter: `POST https://ai.api.cloud.yandex.net/v1/responses`; полный URI только из серверной конфигурации, без клиентского выбора модели/URL. Старый `/translate` сохраняется. [Responses create](https://aistudio.yandex.ru/ru/docs/ai-studio/api/Responses/createResponse).
- Общая схема содержит `reasoning.effort: none`, но поддержка выключения reasoning именно V4.1 Flash в просмотренных страницах не установлена. Не переносить параметры прямого DeepSeek API и не обещать отключение до проверки карточки/минимального согласованного smoke. [Reasoning](https://aistudio.yandex.ru/ru/docs/ai-studio/concepts/generation/chain-of-thought).
- Для минимизации хранения нужны одновременно `store:false` в Responses и `x-data-logging-enabled:false` в header. Это разные настройки. Инструменты/functions/URL не передавать. [Отключение логирования](https://aistudio.yandex.ru/ru/docs/ai-studio/operations/disable-logging), [Responses schema](https://aistudio.yandex.ru/ru/docs/ai-studio/api/Responses/createResponse).
- Scope в примере: `yc.ai.foundationModels.execute`; общая auth-страница для Responses указывает `ai.assistants.editor` и `ai.languageModels.user`. Существующие права нужно проверить; автоматически расширять их нельзя. [Authentication](https://aistudio.yandex.ru/en/docs/ai-studio/api-ref/authentication).

Следующий server slice требует проверки существующей авторизации/tenant, квот, фактического доступа к V4.1, разрешённого JSON output контракта, reasoning-off, региона и согласованного тестового бюджета. Стоимость и тарифы этим preflight не установлены. Доступность каталога не доказывает качество, задержку или доступ конкретного аккаунта. Никакой автоматический fallback не предусматривается.


Уточнение пользовательского сценария: нужен короткий перевод надписей внутри визуальной копии UI, а не отдельный список текста. Версия будущего prompt должна допускать общепринятые интерфейсные сокращения («кол-во», «шт.», «нерж. сталь») без потери характеристик, чисел, отрицаний, валют, единиц, артикулов и брендов. Сокращение не подменяет проверку полноты и числовой инвариант. Изображение провайдеру не передаётся; компоновка и координаты остаются локальными. Пользователь требует полный текст на одной портретной странице без многоточий.
