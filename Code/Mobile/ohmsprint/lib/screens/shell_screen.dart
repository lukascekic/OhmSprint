import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/connection_state.dart';
import '../providers/connection_provider.dart';
import '../widgets/common/connection_lost_overlay.dart';
import '../widgets/nav/bottom_nav_bar.dart';
import 'charts_screen.dart';
import 'dashboard_screen.dart';
import 'power_quality_screen.dart';
import 'settings_screen.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static const List<_ShellDestination> _destinations = [
    _ShellDestination(label: 'Dashboard', path: '/dashboard'),
    _ShellDestination(label: 'Charts', path: '/charts'),
    _ShellDestination(label: 'Quality', path: '/quality'),
    _ShellDestination(label: 'Settings', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _destinations.indexWhere(
      (destination) => location.startsWith(destination.path),
    );
    final safeIndex = currentIndex < 0 ? 0 : currentIndex;
    final connectionState = ref.watch(connectionProvider);
    final showConnectionOverlay =
        connectionState.status == ConnectionStatus.disconnected ||
            connectionState.status == ConnectionStatus.reconnecting;

    assert(() {
      if (currentIndex < 0) {
        debugPrint('ShellScreen received an unexpected route: $location');
      }
      return true;
    }());

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: safeIndex,
              children: const [
                DashboardScreen(),
                ChartsScreen(),
                PowerQualityScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          if (currentIndex < 0) Positioned.fill(child: child),
          if (showConnectionOverlay)
            ConnectionLostOverlay(
              onRetry: () {
                ref.read(connectionProvider.notifier).connect(
                      connectionState.ipAddress ?? '192.168.4.1',
                      port: connectionState.port,
                    );
              },
            ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: safeIndex,
        onTap: (index) => context.go(_destinations[index].path),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.path,
  });

  final String label;
  final String path;
}
