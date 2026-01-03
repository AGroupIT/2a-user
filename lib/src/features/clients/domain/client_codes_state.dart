class ClientCodesState {
  final List<String> codes;
  final String? activeCode;

  const ClientCodesState({
    required this.codes,
    required this.activeCode,
  });

  ClientCodesState copyWith({
    List<String>? codes,
    String? activeCode,
  }) {
    return ClientCodesState(
      codes: codes ?? this.codes,
      activeCode: activeCode ?? this.activeCode,
    );
  }
}

