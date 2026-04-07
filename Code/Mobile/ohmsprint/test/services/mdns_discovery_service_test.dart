import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:ohmsprint/services/mdns_discovery_service.dart';

void main() {
  test('returns empty list when scan yields no services', () async {
    final service = MdnsDiscoveryService(
      clientFactory: () => _FakeMdnsClient(),
    );

    final devices =
        await service.scan(timeout: const Duration(milliseconds: 5));

    expect(devices, isEmpty);
  });

  test('resolves discovered service into name, ip, and port', () async {
    final client = _FakeMdnsClient(
      responses: {
        '12:_ohmsprint._tcp.local': [
          const PtrResourceRecord(
            '_ohmsprint._tcp.local',
            0,
            domainName: 'EnergyMeter-A3F2._ohmsprint._tcp.local',
          ),
        ],
        '33:EnergyMeter-A3F2._ohmsprint._tcp.local': [
          const SrvResourceRecord(
            'EnergyMeter-A3F2._ohmsprint._tcp.local',
            0,
            target: 'esp32.local',
            port: 80,
            priority: 0,
            weight: 0,
          ),
        ],
        '1:esp32.local': [
          IPAddressResourceRecord(
            'esp32.local',
            0,
            address: InternetAddress('192.168.4.1'),
          ),
        ],
      },
    );
    final service = MdnsDiscoveryService(clientFactory: () => client);

    final devices =
        await service.scan(timeout: const Duration(milliseconds: 5));

    expect(devices, hasLength(1));
    expect(devices.single.name, 'EnergyMeter-A3F2');
    expect(devices.single.ip, '192.168.4.1');
    expect(devices.single.port, 80);
  });
}

class _FakeMdnsClient extends MDnsClient {
  _FakeMdnsClient({
    Map<String, List<ResourceRecord>>? responses,
  }) : _responses = responses ?? const {};

  final Map<String, List<ResourceRecord>> _responses;

  @override
  Future<void> start({
    InternetAddress? listenAddress,
    NetworkInterfacesFactory? interfacesFactory,
    int mDnsPort = 5353,
    InternetAddress? mDnsAddress,
    Function? onError,
  }) async {}

  @override
  void stop() {}

  @override
  Stream<T> lookup<T extends ResourceRecord>(
    ResourceRecordQuery query, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    final key = '${query.resourceRecordType}:${query.fullyQualifiedName}';
    final records = _responses[key] ?? const [];
    return Stream<T>.fromIterable(records.cast<T>());
  }
}
