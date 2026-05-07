import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HttpPollingService {
  HttpPollingService(
    this.baseUrl, {
    http.Client? client,
    this.maxConsecutiveFailures = 5,
    this.endpointPaths = const ['/api/readings', '/api/measurements'],
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final int maxConsecutiveFailures;
  final List<String> endpointPaths;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _timer;
  bool _disposed = false;
  int _consecutiveFailures = 0;

  Stream<Map<String, dynamic>> start({
    Duration interval = const Duration(seconds: 1),
  }) {
    if (_disposed) {
      throw StateError('HttpPollingService has been disposed');
    }

    if (_timer != null) {
      return _controller.stream;
    }

    unawaited(_pollOnce());
    _timer = Timer.periodic(interval, (_) {
      unawaited(_pollOnce());
    });

    return _controller.stream;
  }

  Future<void> _pollOnce() async {
    Object? lastError;

    for (final endpointPath in endpointPaths) {
      try {
        final payload = await _pollEndpoint(endpointPath);
        _consecutiveFailures = 0;
        _controller.add(payload);
        return;
      } catch (error) {
        lastError = error;
      }
    }

    debugPrint('HTTP poll failed: $lastError');
    _registerFailure('HTTP polling failed: $lastError');
  }

  Future<Map<String, dynamic>> _pollEndpoint(String endpointPath) async {
    final response = await _client
        .get(Uri.parse('$baseUrl$endpointPath'))
        .timeout(const Duration(seconds: 3));
    if (response.statusCode != 200) {
      throw StateError(
        'HTTP polling returned status ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('HTTP polling returned a non-object payload.');
  }

  void _registerFailure(String message) {
    _consecutiveFailures += 1;
    if (_consecutiveFailures < maxConsecutiveFailures) {
      return;
    }

    _consecutiveFailures = 0;
    _controller.addError(StateError(message));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    stop();
    _disposed = true;
    _client.close();
    await _controller.close();
  }
}
