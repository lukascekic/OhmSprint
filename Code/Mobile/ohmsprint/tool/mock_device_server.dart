import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

enum TransportMode { both, websocketOnly, httpOnly }

enum WebSocketBehavior { stable, disabled, flaky }

Future<void> main(List<String> args) async {
  final config = MockServerConfig.fromArgs(args);
  final server = MockDeviceServer(config);

  await server.start();
  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nStopping mock device server...');
    await server.stop();
    exit(0);
  });
}

class MockServerConfig {
  MockServerConfig({
    required this.host,
    required this.port,
    required this.transportMode,
    required this.webSocketBehavior,
    required this.interval,
    required this.wsEventEvery,
    required this.httpEventEvery,
    required this.wsCloseAfterMessages,
    required this.wsOutage,
    required this.seed,
  });

  final String host;
  final int port;
  final TransportMode transportMode;
  final WebSocketBehavior webSocketBehavior;
  final Duration interval;
  final int wsEventEvery;
  final int httpEventEvery;
  final int wsCloseAfterMessages;
  final Duration wsOutage;
  final int seed;

  MockServerConfig copyWith({
    String? host,
    int? port,
    TransportMode? transportMode,
    WebSocketBehavior? webSocketBehavior,
    Duration? interval,
    int? wsEventEvery,
    int? httpEventEvery,
    int? wsCloseAfterMessages,
    Duration? wsOutage,
    int? seed,
  }) {
    return MockServerConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      transportMode: transportMode ?? this.transportMode,
      webSocketBehavior: webSocketBehavior ?? this.webSocketBehavior,
      interval: interval ?? this.interval,
      wsEventEvery: wsEventEvery ?? this.wsEventEvery,
      httpEventEvery: httpEventEvery ?? this.httpEventEvery,
      wsCloseAfterMessages: wsCloseAfterMessages ?? this.wsCloseAfterMessages,
      wsOutage: wsOutage ?? this.wsOutage,
      seed: seed ?? this.seed,
    );
  }

  Map<String, Object> toJson() {
    return {
      'host': host,
      'port': port,
      'transportMode': transportMode.name,
      'webSocketBehavior': webSocketBehavior.name,
      'intervalMs': interval.inMilliseconds,
      'wsEventEvery': wsEventEvery,
      'httpEventEvery': httpEventEvery,
      'wsCloseAfterMessages': wsCloseAfterMessages,
      'wsOutageSeconds': wsOutage.inSeconds,
      'seed': seed,
    };
  }

  static MockServerConfig fromArgs(List<String> args) {
    final values = <String, String>{};
    for (final arg in args) {
      if (!arg.startsWith('--')) {
        continue;
      }

      final separator = arg.indexOf('=');
      if (separator == -1) {
        values[arg.substring(2)] = 'true';
        continue;
      }

      values[arg.substring(2, separator)] = arg.substring(separator + 1);
    }

    return MockServerConfig(
      host: values['host'] ?? '0.0.0.0',
      port: _parseInt(values['port'], fallback: 8080),
      transportMode: _parseTransport(values['transport']),
      webSocketBehavior: _parseWebSocketBehavior(values['ws-behavior']),
      interval: Duration(
        milliseconds: _parseInt(values['interval-ms'], fallback: 1000),
      ),
      wsEventEvery: _parseInt(values['ws-event-every'], fallback: 18),
      httpEventEvery: _parseInt(values['http-event-every'], fallback: 0),
      wsCloseAfterMessages: _parseInt(values['ws-close-after'], fallback: 0),
      wsOutage: Duration(
        seconds: _parseInt(values['ws-outage-seconds'], fallback: 20),
      ),
      seed: _parseInt(values['seed'], fallback: 42),
    );
  }

  static int _parseInt(String? value, {required int fallback}) {
    return int.tryParse(value ?? '') ?? fallback;
  }

  static TransportMode _parseTransport(String? value) {
    return switch (value) {
      'ws' || 'websocket' => TransportMode.websocketOnly,
      'http' => TransportMode.httpOnly,
      _ => TransportMode.both,
    };
  }

  static WebSocketBehavior _parseWebSocketBehavior(String? value) {
    return switch (value) {
      'disabled' => WebSocketBehavior.disabled,
      'flaky' => WebSocketBehavior.flaky,
      _ => WebSocketBehavior.stable,
    };
  }
}

class MockDeviceServer {
  MockDeviceServer(MockServerConfig config)
      : _config = config,
        _random = Random(config.seed);

  final Random _random;
  final Set<WebSocket> _clients = <WebSocket>{};

  late MockServerConfig _config;
  HttpServer? _httpServer;
  Timer? _tickTimer;
  MeasurementSample _latestMeasurement = MeasurementSample.initial();
  int _tickCount = 0;
  int _httpRequestCount = 0;
  int _wsMessageCount = 0;
  DateTime? _wsUnavailableUntil;

  Future<void> start() async {
    _httpServer = await HttpServer.bind(_config.host, _config.port);
    _httpServer!.listen(_handleRequest);
    _scheduleTicker();

    stdout.writeln('Mock device server running on '
        'http://${_httpServer!.address.host}:${_httpServer!.port}');
    stdout.writeln('  transport=${_config.transportMode.name}'
        ' ws=${_config.webSocketBehavior.name}'
        ' interval=${_config.interval.inMilliseconds}ms');
    stdout.writeln('  ws endpoint:   /ws');
    stdout.writeln('  http endpoint: /api/readings');
    stdout.writeln('  firmware alias: /api/measurements');
    stdout.writeln('  config:        /mock/config');
    stdout.writeln('  status:        /mock/status');
  }

  Future<void> stop() async {
    _tickTimer?.cancel();
    final clients = List<WebSocket>.from(_clients);
    _clients.clear();
    for (final client in clients) {
      await client.close(WebSocketStatus.normalClosure, 'Server stopping');
    }
    await _httpServer?.close(force: true);
  }

  void _scheduleTicker() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(_config.interval, (_) {
      _onTick();
    });
  }

  void _onTick() {
    _tickCount += 1;
    _latestMeasurement = _latestMeasurement.next(_random, _config.interval);

    if (_supportsWebSocket()) {
      _broadcast(_latestMeasurement.toJson());

      if (_config.wsEventEvery > 0 && _tickCount % _config.wsEventEvery == 0) {
        _broadcast(_buildEvent().toJson());
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    try {
      if (path == '/ws') {
        await _handleWebSocketRequest(request);
        return;
      }

      if (path == '/api/readings' || path == '/api/measurements') {
        await _handleReadingsRequest(request);
        return;
      }

      if (path == '/mock/config') {
        await _handleConfigRequest(request);
        return;
      }

      if (path == '/mock/status') {
        await _writeJson(
          request.response,
          {
            'config': _config.toJson(),
            'latestMeasurement': _latestMeasurement.toJson(),
            'connectedClients': _clients.length,
            'tickCount': _tickCount,
            'wsUnavailableUntil': _wsUnavailableUntil?.toIso8601String(),
          },
        );
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await _writeJson(
        request.response,
        {
          'error': 'Unknown path',
          'path': path,
        },
      );
    } catch (error, stackTrace) {
      request.response.statusCode = HttpStatus.internalServerError;
      await _writeJson(
        request.response,
        {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  Future<void> _handleWebSocketRequest(HttpRequest request) async {
    if (!_supportsWebSocket()) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await _writeJson(
        request.response,
        {
          'error': 'WebSocket transport is disabled right now.',
          'transportMode': _config.transportMode.name,
          'webSocketBehavior': _config.webSocketBehavior.name,
        },
      );
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    _clients.add(socket);
    stdout.writeln(
      '[WS] client connected (${_clients.length} total)',
    );

    socket.add(jsonEncode(_latestMeasurement.toJson()));
    socket.listen(
      (message) {
        stdout.writeln('[WS] received from client: $message');
      },
      onDone: () {
        _clients.remove(socket);
        stdout.writeln(
          '[WS] client disconnected (${_clients.length} total)',
        );
      },
      onError: (_) {
        _clients.remove(socket);
      },
      cancelOnError: true,
    );
  }

  Future<void> _handleReadingsRequest(HttpRequest request) async {
    if (!_supportsHttp()) {
      request.response.statusCode = HttpStatus.notFound;
      await _writeJson(
        request.response,
        {
          'error': 'HTTP polling endpoint is disabled.',
          'transportMode': _config.transportMode.name,
        },
      );
      return;
    }

    _httpRequestCount += 1;
    final shouldReturnEvent = _config.httpEventEvery > 0 &&
        _httpRequestCount % _config.httpEventEvery == 0;

    await _writeJson(
      request.response,
      shouldReturnEvent
          ? _buildEvent().toJson()
          : _latestMeasurement.toJson(),
    );
  }

  Future<void> _handleConfigRequest(HttpRequest request) async {
    final updated = _applyConfigQuery(request.uri.queryParameters);
    if (updated.interval != _config.interval) {
      _config = updated;
      _scheduleTicker();
    } else {
      _config = updated;
    }

    await _writeJson(
      request.response,
      {
        'config': _config.toJson(),
        'usage': {
          'example':
              '/mock/config?transport=http&ws-behavior=disabled&http-event-every=8',
        },
      },
    );
  }

  MockServerConfig _applyConfigQuery(Map<String, String> query) {
    if (query.isEmpty) {
      return _config;
    }

    final updated = _config.copyWith(
      transportMode: query.containsKey('transport')
          ? MockServerConfig._parseTransport(query['transport'])
          : null,
      webSocketBehavior: query.containsKey('ws-behavior')
          ? MockServerConfig._parseWebSocketBehavior(query['ws-behavior'])
          : null,
      interval: query.containsKey('interval-ms')
          ? Duration(
              milliseconds: MockServerConfig._parseInt(
                query['interval-ms'],
                fallback: _config.interval.inMilliseconds,
              ),
            )
          : null,
      wsEventEvery: query.containsKey('ws-event-every')
          ? MockServerConfig._parseInt(
              query['ws-event-every'],
              fallback: _config.wsEventEvery,
            )
          : null,
      httpEventEvery: query.containsKey('http-event-every')
          ? MockServerConfig._parseInt(
              query['http-event-every'],
              fallback: _config.httpEventEvery,
            )
          : null,
      wsCloseAfterMessages: query.containsKey('ws-close-after')
          ? MockServerConfig._parseInt(
              query['ws-close-after'],
              fallback: _config.wsCloseAfterMessages,
            )
          : null,
      wsOutage: query.containsKey('ws-outage-seconds')
          ? Duration(
              seconds: MockServerConfig._parseInt(
                query['ws-outage-seconds'],
                fallback: _config.wsOutage.inSeconds,
              ),
            )
          : null,
    );

    stdout.writeln('[CONFIG] updated: ${jsonEncode(updated.toJson())}');
    return updated;
  }

  bool _supportsWebSocket() {
    if (_config.transportMode == TransportMode.httpOnly) {
      return false;
    }
    if (_config.webSocketBehavior == WebSocketBehavior.disabled) {
      return false;
    }
    if (_wsUnavailableUntil != null &&
        DateTime.now().isBefore(_wsUnavailableUntil!)) {
      return false;
    }
    return true;
  }

  bool _supportsHttp() {
    return _config.transportMode != TransportMode.websocketOnly;
  }

  void _broadcast(Map<String, Object> payload) {
    if (_clients.isEmpty) {
      return;
    }

    final message = jsonEncode(payload);
    final staleClients = <WebSocket>[];
    for (final client in _clients) {
      try {
        client.add(message);
      } catch (_) {
        staleClients.add(client);
      }
    }
    _clients.removeAll(staleClients);

    if (_config.webSocketBehavior == WebSocketBehavior.flaky &&
        _config.wsCloseAfterMessages > 0) {
      _wsMessageCount += 1;
      if (_wsMessageCount >= _config.wsCloseAfterMessages) {
        _wsMessageCount = 0;
        _wsUnavailableUntil = DateTime.now().add(_config.wsOutage);
        stdout.writeln(
          '[WS] simulating outage until ${_wsUnavailableUntil!.toIso8601String()}',
        );
        final clients = List<WebSocket>.from(_clients);
        _clients.clear();
        for (final client in clients) {
          unawaited(
            client.close(
              WebSocketStatus.goingAway,
              'Simulated outage for fallback testing',
            ),
          );
        }
      }
    }
  }

  PowerEventSample _buildEvent() {
    final typeIndex = _random.nextInt(4);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return switch (typeIndex) {
      0 => PowerEventSample(
          eventType: 'sag',
          timestamp: timestamp,
          values: {
            'v': (_latestMeasurement.voltage - (12 + (_random.nextDouble() * 8)))
                .clamp(180, 220),
          },
        ),
      1 => PowerEventSample(
          eventType: 'swell',
          timestamp: timestamp,
          values: {
            'v': (_latestMeasurement.voltage + (12 + (_random.nextDouble() * 8)))
                .clamp(240, 265),
          },
        ),
      2 => PowerEventSample(
          eventType: 'freq',
          timestamp: timestamp,
          values: {
            'f': (_latestMeasurement.frequency +
                    (_random.nextBool() ? -0.65 : 0.65))
                .clamp(48.8, 51.2),
          },
        ),
      _ => PowerEventSample(
          eventType: 'lpf',
          timestamp: timestamp,
          values: {
            'pf': (_latestMeasurement.powerFactor - (0.18 + _random.nextDouble() * 0.12))
                .clamp(0.45, 0.85),
          },
        ),
    };
  }

  Future<void> _writeJson(HttpResponse response, Object payload) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(payload));
    await response.close();
  }
}

class MeasurementSample {
  const MeasurementSample({
    required this.voltage,
    required this.current,
    required this.currentN,
    required this.activePower,
    required this.reactivePower,
    required this.apparentPower,
    required this.frequency,
    required this.powerFactor,
    required this.importEnergy,
    required this.exportEnergy,
    required this.timestamp,
  });

  final double voltage;
  final double current;
  final double currentN;
  final double activePower;
  final double reactivePower;
  final double apparentPower;
  final double frequency;
  final double powerFactor;
  final double importEnergy;
  final double exportEnergy;
  final int timestamp;

  factory MeasurementSample.initial() {
    return MeasurementSample(
      voltage: 229.8,
      current: 4.1,
      currentN: 4.0,
      activePower: 915,
      reactivePower: 58,
      apparentPower: 917,
      frequency: 50.0,
      powerFactor: 0.985,
      importEnergy: 1.4,
      exportEnergy: 0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  MeasurementSample next(Random random, Duration interval) {
    final nextVoltage = _walk(random, voltage, sigma: 1.6, min: 205, max: 254);
    final nextCurrent = _walk(random, current, sigma: 0.28, min: 0.1, max: 16);
    final nextCurrentN =
        _walk(random, (currentN + nextCurrent) / 2, sigma: 0.16, min: 0, max: 16);
    final nextFrequency =
        _walk(random, frequency, sigma: 0.02, min: 49.2, max: 50.8);
    final nextPowerFactor =
        _walk(random, powerFactor, sigma: 0.01, min: 0.72, max: 1);
    final nextApparentPower = nextVoltage * nextCurrent;
    final nextActivePower = nextApparentPower * nextPowerFactor;
    final reactiveMagnitude = max(
      0,
      (nextApparentPower * nextApparentPower) -
          (nextActivePower * nextActivePower),
    );
    final nextReactivePower = sqrt(reactiveMagnitude);
    final intervalHours =
        interval.inMilliseconds / Duration.millisecondsPerHour;

    return MeasurementSample(
      voltage: double.parse(nextVoltage.toStringAsFixed(2)),
      current: double.parse(nextCurrent.toStringAsFixed(3)),
      currentN: double.parse(nextCurrentN.toStringAsFixed(3)),
      activePower: double.parse(nextActivePower.toStringAsFixed(1)),
      reactivePower: double.parse(nextReactivePower.toStringAsFixed(1)),
      apparentPower: double.parse(nextApparentPower.toStringAsFixed(1)),
      frequency: double.parse(nextFrequency.toStringAsFixed(2)),
      powerFactor: double.parse(nextPowerFactor.toStringAsFixed(3)),
      importEnergy: double.parse(
        (importEnergy + ((nextActivePower / 1000) * intervalHours))
            .toStringAsFixed(4),
      ),
      exportEnergy: exportEnergy,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object> toJson() {
    return {
      'v': voltage,
      'i': current,
      'in': currentN,
      'p': activePower,
      'q': reactivePower,
      's': apparentPower,
      'f': frequency,
      'pf': powerFactor,
      'ei': importEnergy,
      'ee': exportEnergy,
      't': timestamp,
    };
  }

  static double _walk(
    Random random,
    double currentValue, {
    required double sigma,
    required double min,
    required double max,
  }) {
    final candidate = currentValue + ((random.nextDouble() * 2) - 1) * sigma;
    return candidate.clamp(min, max);
  }
}

class PowerEventSample {
  const PowerEventSample({
    required this.eventType,
    required this.timestamp,
    required this.values,
  });

  final String eventType;
  final int timestamp;
  final Map<String, double> values;

  Map<String, Object> toJson() {
    return {
      'ev': eventType,
      ...values,
      'ts': timestamp,
    };
  }
}
