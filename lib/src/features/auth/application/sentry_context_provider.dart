import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/config/sentry_config.dart';
import '../../clients/application/client_codes_controller.dart';
import '../data/auth_provider.dart';

final sentryContextProvider = Provider<void>((ref) {
  final authState = ref.watch(authProvider);
  final activeClientCode = ref.watch(activeClientCodeProvider);

  if (!SentryConfig.enabled) return;

  unawaited(_syncSentryScope(authState, activeClientCode));
});

Future<void> _syncSentryScope(
  AuthState authState,
  String? activeClientCode,
) async {
  await Sentry.configureScope((scope) async {
    if (!authState.isLoggedIn) {
      await scope.setUser(null);
      await scope.removeTag('auth');
      await scope.removeTag('agent_id');
      await scope.removeTag('agent_domain');
      await scope.removeTag('client_code');
      await scope.removeContexts('client');
      await scope.removeContexts('agent');
      return;
    }

    final clientData = authState.clientData;
    final agentData = clientData?['agent'] as Map<String, dynamic>?;
    final agentId = agentData?['id']?.toString();
    final agentDomain =
        agentData?['domain']?.toString() ?? authState.userDomain;
    final codes = clientData?['codes'] as List<dynamic>?;

    final clientId = authState.clientId?.toString();
    if (clientId == null || clientId.isEmpty) {
      await scope.setUser(null);
    } else {
      await scope.setUser(
        SentryUser(
          id: clientId,
          data: <String, dynamic>{
            'type': 'client',
            if (codes != null) 'codes_count': codes.length,
          },
        ),
      );
    }
    await scope.setTag('auth', 'client');
    if (agentId != null && agentId.isNotEmpty) {
      await scope.setTag('agent_id', agentId);
    } else {
      await scope.removeTag('agent_id');
    }
    if (agentDomain != null && agentDomain.isNotEmpty) {
      await scope.setTag('agent_domain', agentDomain);
    } else {
      await scope.removeTag('agent_domain');
    }
    if (activeClientCode != null && activeClientCode.isNotEmpty) {
      await scope.setTag('client_code', activeClientCode);
    } else {
      await scope.removeTag('client_code');
    }

    await scope.setContexts('client', <String, dynamic>{
      if (authState.clientId != null) 'id': authState.clientId,
      if (activeClientCode != null) 'active_code': activeClientCode,
      if (codes != null) 'codes_count': codes.length,
    });
    await scope.setContexts('agent', <String, dynamic>{
      if (agentId != null) 'id': agentId,
      if (agentDomain != null) 'domain': agentDomain,
    });
  });
}
