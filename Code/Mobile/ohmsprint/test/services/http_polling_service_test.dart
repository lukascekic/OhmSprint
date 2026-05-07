import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ohmsprint/services/http_polling_service.dart';

void main() {
  test('emits parsed json from the polling endpoint', () async {
    final service = HttpPollingService(
      'http://device.local',
      client: MockClient((request) async {
        expect(request.url.toString(), 'http://device.local/api/readings');
        return http.Response(
          '{"v":230.0,"i":4.0,"p":920.0,"f":50.0,"pf":0.99,"t":12345}',
          200,
        );
      }),
    );

    addTearDown(service.dispose);

    final payload =
        await service.start(interval: const Duration(milliseconds: 10)).first;

    expect(payload['v'], 230.0);
    expect(payload['p'], 920.0);
    expect(payload['t'], 12345);
  });

  test('falls back to firmware measurements endpoint', () async {
    final service = HttpPollingService(
      'http://device.local',
      client: MockClient((request) async {
        if (request.url.path == '/api/readings') {
          return http.Response('not found', 404);
        }
        expect(request.url.toString(), 'http://device.local/api/measurements');
        return http.Response(
          '{"voltage":230.0,"current":4.0,"power":920.0,"frequency":50.0,"power_usage":1.2,"timestamp":42}',
          200,
        );
      }),
    );

    addTearDown(service.dispose);

    final payload =
        await service.start(interval: const Duration(milliseconds: 10)).first;

    expect(payload['voltage'], 230.0);
    expect(payload['power_usage'], 1.2);
  });

  test('emits an error after repeated polling failures', () async {
    final service = HttpPollingService(
      'http://device.local',
      maxConsecutiveFailures: 2,
      client: MockClient((request) async {
        return http.Response('offline', 503);
      }),
    );

    addTearDown(service.dispose);

    expect(
      service.start(interval: const Duration(milliseconds: 10)),
      emitsError(isA<StateError>()),
    );
  });
}
