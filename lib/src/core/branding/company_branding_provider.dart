import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_provider.dart';
import '../../features/profile/data/profile_provider.dart';

const fallbackCompanyName = 'Личный кабинет';

String resolveCompanyName({String? profileAgentName, String? authAgentName}) {
  final profileName = profileAgentName?.trim();
  if (profileName?.isNotEmpty == true) return profileName!;

  final authName = authAgentName?.trim();
  if (authName?.isNotEmpty == true) return authName!;

  return fallbackCompanyName;
}

/// Название компании текущего агента для любого пользовательского текста.
/// Профиль является основным источником, а данные авторизации позволяют не
/// показывать чужой бренд, пока профиль ещё загружается или недоступен офлайн.
final companyNameProvider = Provider<String>((ref) {
  final profile = ref.watch(clientProfileProvider).asData?.value;
  final authAgent = ref.watch(authProvider).clientData?['agent'];
  final authAgentName = authAgent is Map<String, dynamic>
      ? authAgent['name'] as String?
      : null;

  return resolveCompanyName(
    profileAgentName: profile?.agent?.name,
    authAgentName: authAgentName,
  );
});
