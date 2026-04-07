import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static const List<_ShellDestination> _destinations = [
    _ShellDestination(
        label: 'Dashboard', icon: Icons.dashboard_outlined, path: '/dashboard'),
    _ShellDestination(label: 'Charts', icon: Icons.show_chart, path: '/charts'),
    _ShellDestination(label: 'Quality', icon: Icons.tune, path: '/quality'),
    _ShellDestination(
        label: 'Settings', icon: Icons.settings_outlined, path: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _destinations.indexWhere(
      (destination) => location.startsWith(destination.path),
    );

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (index) {
          context.go(_destinations[index].path);
        },
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}
