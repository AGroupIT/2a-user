import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/services/agent_domain_resolver.dart';

void main() {
  group('AgentDomainResolver', () {
    test('maps cabinet hosts to agent domains', () {
      expect(
        AgentDomainResolver.agentDomainFromHost('cabinet.iop-cargo.ru'),
        'iop-cargo.ru',
      );
      expect(
        AgentDomainResolver.agentDomainFromHost('cabinet.teamtime-logistic.ru'),
        'teamtime-logistic.ru',
      );
      expect(
        AgentDomainResolver.agentDomainFromHost('cabinet.2a-logistic.ru'),
        '2a-logistic.ru',
      );
      expect(
        AgentDomainResolver.agentDomainFromHost('cabinet.k8-cargo.ru'),
        'k8-cargo.ru',
      );
    });

    test('normalizes case, www prefix, and port', () {
      expect(
        AgentDomainResolver.agentDomainFromHost('WWW.CABINET.IOP-CARGO.RU:443'),
        'iop-cargo.ru',
      );
    });

    test('ignores unknown and native hosts', () {
      expect(AgentDomainResolver.agentDomainFromHost(null), isNull);
      expect(AgentDomainResolver.agentDomainFromHost('localhost'), isNull);
      expect(
        AgentDomainResolver.agentDomainFromHost('prod-api.cp.2a-logistic.com'),
        isNull,
      );
    });
  });
}
