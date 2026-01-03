import 'package:flutter/widgets.dart';

class AppLayout {
  const AppLayout._();

  static const topBarHeight = 56.0;
  static const topBarTopMargin = 10.0;
  static const topBarBottomGap = 12.0;

  static const bottomBarHeight = 74.0;
  static const bottomBarBottomMargin = 10.0;
  static const bottomBarExtraScrollPadding = 12.0;

  static double topBarTotalHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top + topBarTopMargin + topBarHeight + topBarBottomGap;
  }

  static double bottomBarObstruction(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + bottomBarHeight + bottomBarBottomMargin;
  }

  static double bottomScrollPadding(BuildContext context) {
    return bottomBarObstruction(context) + bottomBarExtraScrollPadding;
  }
}
