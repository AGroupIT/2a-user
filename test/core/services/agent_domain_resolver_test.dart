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

    test(
      'derives new cabinet domains without adding a release-time mapping',
      () {
        for (final domain in [
          'keshadostavka.ru',
          'future-company.com',
          'cargo.example.co.uk',
          'xn--e1afmkfd.xn--p1ai',
        ]) {
          expect(
            AgentDomainResolver.agentDomainFromHost('cabinet.$domain'),
            domain,
          );
        }
        expect(
          AgentDomainResolver.agentDomainFromHost(
            'WWW.CABINET.KESHADOSTAVKA.RU:443',
          ),
          'keshadostavka.ru',
        );
      },
    );

    test('rejects malformed authorities, URLs, local hosts and IPs', () {
      final longLabel = List.filled(64, 'a').join();
      final longHost = List.filled(40, 'longlabel').join('.');
      for (final host in [
        '',
        ' ',
        'keshadostavka.ru',
        'api.keshadostavka.ru',
        'https://cabinet.keshadostavka.ru',
        '//cabinet.keshadostavka.ru',
        'user@cabinet.keshadostavka.ru',
        'cabinet.keshadostavka.ru@evil.ru',
        'cabinet.keshadostavka.ru/',
        'cabinet.keshadostavka.ru/path',
        'cabinet.keshadostavka.ru?x=1',
        'cabinet.keshadostavka.ru#x',
        'cabinet.keshadostavka.ru:abc',
        'cabinet.keshadostavka.ru:',
        'cabinet.keshadostavka.ru:0',
        'cabinet.keshadostavka.ru:65536',
        'cabinet.keshadostavka.ru:443:80',
        'cabinet.keshadostavka.ru:-1',
        'cabinet..ru',
        'cabinet.-cargo.ru',
        'cabinet.cargo-.ru',
        'cabinet.cargo_name.ru',
        'cabinet.cargo.ru.',
        'cabinet.car go.ru',
        'cabinet.$longLabel.ru',
        'cabinet.$longHost.ru',
        'cabinet.localhost',
        'cabinet.company.local',
        'cabinet.company.internal',
        'cabinet.company.invalid',
        'cabinet.company.test',
        'cabinet.company',
        'cabinet.127.0.0.1',
        '127.0.0.1',
        '[::1]',
        'cabinet.[::1]',
        'cabinet.company.123',
        'cabinet.company.c',
      ]) {
        expect(
          AgentDomainResolver.agentDomainFromHost(host),
          isNull,
          reason: host,
        );
      }
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
