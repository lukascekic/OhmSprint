import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

typedef MDnsClientFactory = MDnsClient Function();

class DiscoveredDevice {
  const DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.port,
  });

  final String name;
  final String ip;
  final int port;
}

class MdnsDiscoveryService {
  MdnsDiscoveryService({
    MDnsClientFactory? clientFactory,
  }) : _clientFactory = clientFactory ?? _createClient;

  static const String primaryServiceType = '_ohmsprint._tcp.local';
  static const String fallbackServiceType = '_http._tcp.local';

  final MDnsClientFactory _clientFactory;

  static MDnsClient _createClient() {
    return MDnsClient(rawDatagramSocketFactory: _bindDatagramSocket);
  }

  static Future<RawDatagramSocket> _bindDatagramSocket(
    dynamic host,
    int port, {
    bool reuseAddress = true,
    bool reusePort = true,
    int ttl = 255,
  }) {
    return RawDatagramSocket.bind(
      host,
      port,
      reuseAddress: reuseAddress,
      // Android's Dart socket backend can reject SO_REUSEPORT; SO_REUSEADDR is
      // enough for the one-shot discovery flow used by this app.
      reusePort: false,
      ttl: ttl,
    );
  }

  Future<List<DiscoveredDevice>> scan({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final client = _clientFactory();
    final devices = <String, DiscoveredDevice>{};

    await client.start();
    try {
      await _scanServiceType(
        client,
        primaryServiceType,
        timeout,
        devices,
      );

      if (devices.isEmpty) {
        await _scanServiceType(
          client,
          fallbackServiceType,
          timeout,
          devices,
        );
      }
    } finally {
      client.stop();
    }

    final results = devices.values.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  Future<void> _scanServiceType(
    MDnsClient client,
    String serviceType,
    Duration timeout,
    Map<String, DiscoveredDevice> devices,
  ) async {
    await for (final ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(serviceType),
      timeout: timeout,
    )) {
      await for (final srv in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
        timeout: timeout,
      )) {
        await for (final ip in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
          timeout: timeout,
        )) {
          final device = DiscoveredDevice(
            name: _normalizeName(ptr.domainName),
            ip: ip.address.address,
            port: srv.port,
          );
          devices['${device.ip}:${device.port}'] = device;
        }
      }
    }
  }

  String _normalizeName(String rawName) {
    final localTrimmed = rawName.endsWith('.local')
        ? rawName.substring(0, rawName.length - '.local'.length)
        : rawName;
    final serviceSuffix = localTrimmed.indexOf('._');
    final simplified = serviceSuffix >= 0
        ? localTrimmed.substring(0, serviceSuffix)
        : localTrimmed;
    return simplified.replaceAll(RegExp(r'\.+$'), '');
  }
}
