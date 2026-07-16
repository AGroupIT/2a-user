/// Канал распространения текущей сборки.
///
/// Для RuStore-сборки передаётся `--dart-define=APP_DISTRIBUTION=rustore`.
/// Остальные мобильные сборки используют прямой канал по умолчанию.
const appDistribution = String.fromEnvironment(
  'APP_DISTRIBUTION',
  defaultValue: 'direct',
);

bool get isRuStoreDistribution => appDistribution == 'rustore';
