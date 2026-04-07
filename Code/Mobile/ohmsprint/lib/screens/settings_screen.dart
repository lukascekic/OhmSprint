import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Settings Placeholder'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.push('/settings/export'),
              child: const Text('Open Export Placeholder'),
            ),
          ],
        ),
      ),
    );
  }
}
