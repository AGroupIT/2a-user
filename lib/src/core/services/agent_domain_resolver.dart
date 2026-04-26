import 'agent_domain_host_provider_stub.dart'
    if (dart.library.html) 'agent_domain_host_provider_web.dart';

class AgentDomainResolver {
  static const Map<String, String> _cabinetHostToAgentDomain = {
    'cabinet.iop-cargo.ru': 'iop-cargo.ru',
    'cabinet.teamtime-logistic.ru': 'teamtime-logistic.ru',
    'cabinet.2a-logistic.ru': '2a-logistic.ru',
    'cabinet.k8-cargo.ru': 'k8-cargo.ru',
  };

  static String? get currentAgentDomain {
    return agentDomainFromHost(currentHostname());
  }

  static String? agentDomainFromHost(String? rawHost) {
    final host = _normalizeHost(rawHost);
    if (host == null) return null;
    return _cabinetHostToAgentDomain[host];
  }

  static String? _normalizeHost(String? rawHost) {
    final host = rawHost?.trim().toLowerCase();
    if (host == null || host.isEmpty) return null;
    final hostWithoutPort = host.split(':').first;
    if (hostWithoutPort.startsWith('www.')) {
      return hostWithoutPort.substring(4);
    }
    return hostWithoutPort;
  }
}
