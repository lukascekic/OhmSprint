import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/connection_state.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../providers/connection_provider.dart';
import '../providers/demo_mode_provider.dart';
import '../widgets/common/glass_card.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  static const _defaultIp = '192.168.4.1';

  late final AnimationController _pulseController;
  Timer? _demoScanTimer;
  bool _didScheduleDemoConnect = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _demoScanTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _scheduleDemoConnectIfNeeded() {
    if (_didScheduleDemoConnect || !ref.read(demoModeProvider)) {
      return;
    }

    _didScheduleDemoConnect = true;
    _demoScanTimer?.cancel();
    _demoScanTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      ref.read(connectionProvider.notifier).connect(_defaultIp);
    });
  }

  void _resetDemoAutoConnect() {
    _demoScanTimer?.cancel();
    _didScheduleDemoConnect = false;
  }

  bool _isValidIpOrSocketAddress(String input) {
    final value = input.trim();
    final ipv4Pattern = RegExp(
      r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.'
      r'(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.'
      r'(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.'
      r'(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
    );

    return ipv4Pattern.hasMatch(value) ||
        value.startsWith('ws://') ||
        value.startsWith('wss://');
  }

  Future<void> _showManualConnectDialog() async {
    final controller = TextEditingController(text: _defaultIp);

    final ip = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: Text(
            'Connect Manually',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.onSurface,
              fontSize: 22,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurface,
            ),
            decoration: InputDecoration(
              labelText: 'Device IP',
              labelStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              hintText: _defaultIp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (ip == null || ip.isEmpty || !mounted) {
      return;
    }

    if (!_isValidIpOrSocketAddress(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid device IP or WebSocket URL.',
            style: AppTypography.bodyMedium,
          ),
        ),
      );
      return;
    }

    ref.read(connectionProvider.notifier).connect(ip);
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final isDemoMode = ref.watch(demoModeProvider);
    final isBusy = connectionState.status == ConnectionStatus.connecting ||
        connectionState.status == ConnectionStatus.reconnecting;

    ref.listen<DeviceConnectionState>(connectionProvider, (previous, next) {
      if (next.isConnected && context.mounted) {
        context.go('/dashboard');
      }
    });

    if (isDemoMode) {
      _scheduleDemoConnectIfNeeded();
    } else if (_didScheduleDemoConnect) {
      _resetDemoAutoConnect();
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 0.85,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.surfaceDim,
                    AppColors.surfaceDim,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 288,
                    height: 288,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            for (final entry in [
                              (size: 1.0, phase: 0.0, alpha: 0.18),
                              (size: 0.8, phase: 0.24, alpha: 0.26),
                              (size: 0.6, phase: 0.48, alpha: 0.34),
                            ])
                              _ScannerRing(
                                progress:
                                    (_pulseController.value + entry.phase) % 1,
                                baseScale: entry.size,
                                opacity: entry.alpha,
                              ),
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surfaceContainerHigh,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 40,
                                    spreadRadius: 4,
                                  ),
                                ],
                                border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.28),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.wifi_tethering_rounded,
                                color: AppColors.primary,
                                size: 50,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Text(
                    isDemoMode ? 'DEMO LINK ACTIVE' : 'INITIALIZING LINK',
                    style: AppTypography.monoSmall.copyWith(
                      color: AppColors.secondary,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Connecting to EnergyMeter...',
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.onSurface,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isDemoMode
                        ? 'Demo mode simulates discovery and opens a fake data stream after a short scan.'
                        : 'Ensure your device is within range of the hardware module before starting discovery.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  GlassCard(
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'SSID_SCAN',
                          value: isBusy ? 'ACTIVE' : 'IDLE',
                          valueColor: AppColors.secondary,
                        ),
                        _InfoRow(
                          label: 'PROTO',
                          value: isDemoMode ? 'MOCK STREAM' : 'WEBSOCKET',
                        ),
                        _InfoRow(
                          label: 'SIGNAL',
                          value: isDemoMode ? 'SIMULATED' : '-64 dBm',
                          valueColor: AppColors.primary,
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: AppColors.outlineVariant.withValues(
                                  alpha: 0.12,
                                ),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  connectionState.lastError ??
                                      'Searching for broadcast packets...',
                                  style: AppTypography.monoSmall.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isBusy
                          ? null
                          : () => ref
                              .read(connectionProvider.notifier)
                              .connect(_defaultIp),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.surfaceDim,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isBusy ? 'SCANNING...' : 'SCANNING DEVICES',
                        style: AppTypography.headlineMedium.copyWith(
                          fontSize: 18,
                          color: AppColors.surfaceDim,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showManualConnectDialog,
                      icon: const Icon(Icons.keyboard_rounded, size: 18),
                      label: const Text('Connect Manually'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: AppColors.onSurface,
                        side: BorderSide(
                          color:
                              AppColors.outlineVariant.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Reference ID: OM-772-CNX',
                    style: AppTypography.monoSmall.copyWith(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.45),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerRing extends StatelessWidget {
  const _ScannerRing({
    required this.progress,
    required this.baseScale,
    required this.opacity,
  });

  final double progress;
  final double baseScale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final scale = baseScale + (progress * 0.12);
    final fadedOpacity = (1 - progress) * opacity;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: fadedOpacity),
            width: 1,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: AppTypography.monoSmall.copyWith(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          Text(
            value,
            style: AppTypography.monoSmall.copyWith(
              color: valueColor ?? AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
