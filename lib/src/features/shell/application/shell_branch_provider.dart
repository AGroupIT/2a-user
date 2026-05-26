import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract final class ShellBranchIndex {
  static const home = 0;
  static const photos = 1;
  static const tracks = 2;
  static const invoices = 3;
  static const support = 4;
  static const more = 5;
}

class ActiveShellBranchIndexNotifier extends Notifier<int> {
  @override
  int build() => ShellBranchIndex.home;

  void setIndex(int index) => state = index;
}

final activeShellBranchIndexProvider =
    NotifierProvider<ActiveShellBranchIndexNotifier, int>(
      ActiveShellBranchIndexNotifier.new,
    );
