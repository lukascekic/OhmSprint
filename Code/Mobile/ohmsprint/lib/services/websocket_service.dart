import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;

  Stream<Map<String, dynamic>> connect(String url) {
    disconnect();
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _isConnected = true;

    return _channel!.stream
        .transform<Map<String, dynamic>>(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              final message = switch (data) {
                String value => value,
                List<int> value => utf8.decode(value),
                _ => throw const FormatException(
                    'Unsupported websocket payload type'),
              };

              final decoded = jsonDecode(message);
              if (decoded is! Map<String, dynamic>) {
                throw const FormatException(
                  'Expected websocket payload to be a JSON object',
                );
              }
              sink.add(decoded);
            },
            handleError: (error, stackTrace, sink) {
              _isConnected = false;
              sink.addError(error, stackTrace);
            },
            handleDone: (sink) {
              _isConnected = false;
              sink.close();
            },
          ),
        )
        .asBroadcastStream(
          onCancel: (_) => disconnect(),
        );
  }

  void disconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  bool get isConnected => _isConnected;
}
