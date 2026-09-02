enum ClientNotificationPreferencePolicy { configurable, mandatory }

class ClientNotificationPreferenceItem {
  final String key;
  final String eventType;
  final String group;
  final ClientNotificationPreferencePolicy policy;
  final bool enabled;
  final String? targetType;

  const ClientNotificationPreferenceItem({
    required this.key,
    required this.eventType,
    required this.group,
    required this.policy,
    required this.enabled,
    this.targetType,
  });

  bool get isConfigurable =>
      policy == ClientNotificationPreferencePolicy.configurable;

  factory ClientNotificationPreferenceItem.fromJson(Map<String, dynamic> json) {
    return ClientNotificationPreferenceItem(
      key: json['key']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? '',
      group: json['group']?.toString() ?? 'other',
      policy: json['policy'] == 'configurable'
          ? ClientNotificationPreferencePolicy.configurable
          : ClientNotificationPreferencePolicy.mandatory,
      enabled: json['enabled'] as bool? ?? true,
      targetType: json['targetType']?.toString(),
    );
  }

  ClientNotificationPreferenceItem copyWith({bool? enabled}) {
    return ClientNotificationPreferenceItem(
      key: key,
      eventType: eventType,
      group: group,
      policy: policy,
      enabled: enabled ?? this.enabled,
      targetType: targetType,
    );
  }
}

class ClientNotificationPreferencesState {
  final List<ClientNotificationPreferenceItem> items;
  final Set<String> savingKeys;

  const ClientNotificationPreferencesState({
    required this.items,
    this.savingKeys = const {},
  });

  ClientNotificationPreferencesState copyWith({
    List<ClientNotificationPreferenceItem>? items,
    Set<String>? savingKeys,
  }) {
    return ClientNotificationPreferencesState(
      items: items ?? this.items,
      savingKeys: savingKeys ?? this.savingKeys,
    );
  }
}
