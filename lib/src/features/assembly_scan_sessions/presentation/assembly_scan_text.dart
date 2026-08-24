import 'package:flutter/widgets.dart';

import '../../../core/utils/locale_text.dart';

String assemblyScanApproachCountText(BuildContext context, int count) {
  return tr(context, ru: ruApproachCount(count), zh: '$count 次');
}

String assemblyScanTrackCountText(BuildContext context, int count) {
  return tr(context, ru: ruTrackCount(count), zh: '$count 个轨迹');
}

String ruApproachCount(int count) {
  return '$count ${_ruPlural(count, one: 'подход', few: 'подхода', many: 'подходов')}';
}

String ruTrackCount(int count) {
  return '$count ${_ruPlural(count, one: 'трек', few: 'трека', many: 'треков')}';
}

String _ruPlural(
  int count, {
  required String one,
  required String few,
  required String many,
}) {
  final value = count.abs();
  final lastTwo = value % 100;
  if (lastTwo >= 11 && lastTwo <= 14) return many;
  return switch (value % 10) {
    1 => one,
    2 || 3 || 4 => few,
    _ => many,
  };
}
