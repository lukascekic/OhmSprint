import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HttpPollingService {
  HttpPollingService(
    this.baseUrl, {
    http.Client? client,
    this.maxConsecutiveFailures = 5,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final int maxConsecutiveFailures;
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
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/readings'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        _registerFailure(
          'HTTP polling returned status ${response.statusCode}.',
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        _consecutiveFailures = 0;
        _controller.add(decoded);
      } else if (decoded is Map) {
        _consecutiveFailures = 0;
        _controller.add(Map<String, dynamic>.from(decoded));
      } else {
        _registerFailure('HTTP polling returned a non-object payload.');
      }
    } catch (error) {
      debugPrint('HTTP poll failed: $error');
      _registerFailure('HTTP polling failed: $error');
    }
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
