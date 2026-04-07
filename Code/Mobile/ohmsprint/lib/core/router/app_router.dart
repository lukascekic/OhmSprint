import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/connection_provider.dart';
import '../../screens/charts_screen.dart';
import '../../screens/connection_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/export_screen.dart';
import '../../screens/power_quality_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/shell_screen.dart';
import '../../screens/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final connectionStatus = ValueNotifier<bool>(
    ref.read(
      connectionProvider
          .select((connectionState) => connectionState.isConnected),
    ),
  );

  ref.listen<bool>(
    connectionProvider.select((connectionState) => connectionState.isConnected),
    (previous, next) {
      if (previous != next) {
        connectionStatus.value = next;
      }
    },
  );
  ref.onDispose(connectionStatus.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: connectionStatus,
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/connect',
        name: 'connect',
        builder: (context, state) => const ConnectionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return ShellScreen(
            location: state.uri.toString(),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/charts',
            name: 'charts',
            builder: (context, state) => const ChartsScreen(),
          ),
          GoRoute(
            path: '/quality',
            name: 'quality',
            builder: (context, state) => const PowerQualityScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings/export',
        name: 'export',
        builder: (context, state) => const ExportScreen(),
      ),
    ],
    redirect: (context, state) {
      final location = state.uri.toString();
      final isConnected = connectionStatus.value;
      const protectedPaths = [
        '/dashboard',
        '/charts',
        '/quality',
        '/settings',
      ];

      if (location == '/connect' && isConnected) {
        return '/dashboard';
      }

      if (!isConnected &&
          protectedPaths.any((path) => location.startsWith(path))) {
        return '/connect';
      }

      return null;
    },
  );
});
