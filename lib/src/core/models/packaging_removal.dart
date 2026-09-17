/// The legacy partial option deliberately has no target: old orders did not
/// distinguish a box from a bag.
enum PackagingRemovalOption {
  none,
  transportOnly,
  boxOnly,
  bagOnly,
  all;

  String get apiValue => switch (this) {
    none => 'none',
    all => 'all',
    transportOnly || boxOnly || bagOnly => 'transport_only',
  };

  String? get target => switch (this) {
    boxOnly => 'box',
    bagOnly => 'bag',
    _ => null,
  };

  bool isSupported(bool supportsTargets) => target == null || supportsTargets;

  static PackagingRemovalOption fromApi(Object? value, Object? target) {
    return switch (value) {
      'all' => all,
      'transport_only' => switch (target) {
        'box' => boxOnly,
        'bag' => bagOnly,
        _ => transportOnly,
      },
      _ => none,
    };
  }

  static List<PackagingRemovalOption> available({
    required bool supportsTargets,
    PackagingRemovalOption current = none,
  }) => [
    none,
    if (!supportsTargets || current == transportOnly) transportOnly,
    if (supportsTargets) ...[boxOnly, bagOnly],
    all,
  ];

  Map<String, Object?> toApi({required bool supportsTargets}) {
    if (!isSupported(supportsTargets)) {
      throw UnsupportedError('PACKAGING_REMOVAL_TARGETS_UNSUPPORTED');
    }
    return {
      'packagingRemoval': apiValue,
      if (supportsTargets) 'packagingRemovalTarget': target,
    };
  }
}
