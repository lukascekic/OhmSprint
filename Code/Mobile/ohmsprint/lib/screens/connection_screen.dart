import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../providers/demo_mode_provider.dart';

class ConnectionScreen extends ConsumerWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionProvider);
    final isDemoMode = ref.watch(demoModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Connection Screen Placeholder'),
            const SizedBox(height: 12),
            Text('Status: ${connectionState.status.name}'),
            Text('Mode: ${isDemoMode ? 'demo' : 'device'}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ref.read(connectionProvider.notifier).connect('192.168.4.1');
              },
              child: const Text('Connect Placeholder'),
            ),
          ],
        ),
      ),
    );
  }
}
