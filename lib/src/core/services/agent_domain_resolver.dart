import 'agent_domain_host_provider_stub.dart'
    if (dart.library.html) 'agent_domain_host_provider_web.dart';

class AgentDomainResolver {
  static String? get currentAgentDomain {
    return agentDomainFromHost(currentHostname());
  }

  /// A cabinet host supplies a domain candidate, not an authorized tenant.
  /// The API still resolves it against active agents before authenticating.
  static String? agentDomainFromHost(String? rawHost) {
    final host = _normalizeHost(rawHost);
    if (host == null || !host.startsWith('cabinet.')) return null;
    final domain = host.substring('cabinet.'.length);
    final labels = domain.split('.');
    if (labels.length < 2) return null;
    final suffix = labels.last;
    if (const {
      'localhost',
      'local',
      'internal',
      'invalid',
      'test',
    }.contains(suffix)) {
      return null;
    }
    // Numeric suffixes include IPv4 addresses, not public partner domains.
    if (!RegExp(r'^[a-z]{2,63}$').hasMatch(suffix) &&
        !suffix.startsWith('xn--')) {
      return null;
    }
    return domain;
  }

  static String? _normalizeHost(String? rawHost) {
    final value = rawHost?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    // Accept a hostname and optional port only; never a URL or authority.
    final match = RegExp(r'^([a-z0-9.-]+)(?::([0-9]+))?$').firstMatch(value);
    if (match == null) return null;
    final port = match.group(2);
    if (port != null) {
      final number = int.tryParse(port);
      if (number == null || number < 1 || number > 65535) return null;
    }
    var host = match.group(1)!;
    if (host.startsWith('www.')) host = host.substring(4);
    if (host.length > 253) return null;
    final label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
    if (!host.split('.').every(label.hasMatch)) return null;
    return host;
  }
}
