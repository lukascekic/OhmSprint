import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/connection_state.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../providers/connection_provider.dart';
import '../providers/demo_mode_provider.dart';
import '../providers/settings_provider.dart';
import '../services/mdns_discovery_service.dart';
import '../widgets/common/glass_card.dart';

final mdnsDiscoveryServiceProvider = Provider<MdnsDiscoveryService>((ref) {
  return MdnsDiscoveryService();
});

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
  bool _didStartRealScan = false;
  bool _didAutoConnectDiscoveredDevice = false;
  bool _isScanning = false;
  bool _didFinishScan = false;
  DiscoveredDevice? _discoveredDevice;
  String? _scanStatusMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startInitialDiscovery();
    });
  }

  @override
  void dispose() {
    _demoScanTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startInitialDiscovery() {
    if (ref.read(demoModeProvider)) {
      _scheduleDemoConnectIfNeeded();
      return;
    }

    if (_didStartRealScan) {
      return;
    }

    _didStartRealScan = true;
    unawaited(_runMdnsScan(autoConnectIfPossible: true));
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
    final settings = ref.read(settingsProvider);
    final suggestedIp = _discoveredDevice?.ip.isNotEmpty == true
        ? _discoveredDevice!.ip
        : settings.deviceIp;
    final controller = TextEditingController(
      text: suggestedIp.isNotEmpty ? suggestedIp : _defaultIp,
    );

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

    final discoveredPort =
        _discoveredDevice != null && ip == _discoveredDevice!.ip
            ? _discoveredDevice!.port
            : null;
    ref.read(connectionProvider.notifier).connect(ip, port: discoveredPort);
  }

  Future<void> _runMdnsScan({bool autoConnectIfPossible = false}) async {
    if (_isScanning || ref.read(demoModeProvider)) {
      return;
    }

    setState(() {
      _isScanning = true;
      _didFinishScan = false;
      _scanStatusMessage = 'Scanning local network for OhmSprint services...';
    });

    try {
      final devices = await ref.read(mdnsDiscoveryServiceProvider).scan(
            timeout: const Duration(seconds: 5),
          );

      if (!mounted) {
        return;
      }

      if (devices.isEmpty) {
        setState(() {
          _isScanning = false;
          _didFinishScan = true;
          _discoveredDevice = null;
          _scanStatusMessage =
              'No devices found. You can rescan or connect manually.';
        });
        return;
      }

      final device = devices.first;
      setState(() {
        _isScanning = false;
        _didFinishScan = true;
        _discoveredDevice = device;
        _scanStatusMessage =
            '${device.name} discovered at ${device.ip}:${device.port}.';
      });

      if (autoConnectIfPossible &&
          ref.read(settingsProvider).autoConnect &&
          !_didAutoConnectDiscoveredDevice) {
        _didAutoConnectDiscoveredDevice = true;
        ref
            .read(connectionProvider.notifier)
            .connect(device.ip, port: device.port);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isScanning = false;
        _didFinishScan = true;
        _scanStatusMessage =
            'mDNS scan failed. You can rescan or connect manually.';
      });
    }
  }

  Future<void> _handlePrimaryAction() async {
    final isDemoMode = ref.read(demoModeProvider);
    if (isDemoMode) {
      ref.read(connectionProvider.notifier).connect(_defaultIp);
      return;
    }

    final device = _discoveredDevice;
    if (device != null) {
      ref.read(connectionProvider.notifier).connect(
            device.ip,
            port: device.port,
          );
      return;
    }

    await _runMdnsScan();
  }

  String _transportLabel(ConnectionTransport? transport,
      {bool isDemoMode = false}) {
    if (isDemoMode) {
      return 'MOCK STREAM';
    }

    return switch (transport) {
      ConnectionTransport.http => 'HTTP POLLING',
      ConnectionTransport.websocket => 'WEBSOCKET',
      ConnectionTransport.mock => 'MOCK STREAM',
      null => 'mDNS -> WS',
    };
  }

  IconData _transportIcon(ConnectionTransport? transport,
      {bool isDemoMode = false}) {
    if (isDemoMode) {
      return Icons.auto_graph_rounded;
    }

    return switch (transport) {
      ConnectionTransport.http => Icons.sync_alt_rounded,
      ConnectionTransport.websocket => Icons.wifi_tethering_rounded,
      ConnectionTransport.mock => Icons.auto_graph_rounded,
      null => Icons.travel_explore_rounded,
    };
  }

  String _headlineLabel(bool isDemoMode) {
    if (isDemoMode) {
      return 'DEMO LINK ACTIVE';
    }
    if (_isScanning) {
      return 'SCANNING LOCAL NETWORK';
    }
    if (_discoveredDevice != null) {
      return 'DEVICE DISCOVERED';
    }
    return 'INITIALIZING LINK';
  }

  String _primaryButtonLabel(bool isDemoMode) {
    if (isDemoMode) {
      return 'ENTER DEMO STREAM';
    }
    if (_isScanning) {
      return 'SCANNING...';
    }
    if (_discoveredDevice != null) {
      return 'CONNECT DEVICE';
    }
    if (_didFinishScan) {
      return 'RESCAN NETWORK';
    }
    return 'SCAN NETWORK';
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final isDemoMode = ref.watch(demoModeProvider);
    final isBusy = connectionState.status == ConnectionStatus.connecting ||
        connectionState.status == ConnectionStatus.reconnecting;
    final discoveredDevice = _discoveredDevice;
    final connectionMessage = connectionState.lastError ??
        _scanStatusMessage ??
        'Searching for broadcast packets...';

    ref.listen<DeviceConnectionState>(connectionProvider, (previous, next) {
      if (next.isConnected && context.mounted) {
        context.go('/dashboard');
      }
    });

    if (isDemoMode) {
      _scheduleDemoConnectIfNeeded();
    } else {
      if (_didScheduleDemoConnect) {
        _resetDemoAutoConnect();
      }
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
                              child: Icon(
                                _transportIcon(
                                  connectionState.transport,
                                  isDemoMode: isDemoMode,
                                ),
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
                    _headlineLabel(isDemoMode),
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
                        : 'The app first tries mDNS discovery, then falls back to manual IP entry if your device stays silent.',
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
                          value: _isScanning
                              ? 'ACTIVE'
                              : (_didFinishScan ? 'COMPLETE' : 'IDLE'),
                          valueColor: _isScanning
                              ? AppColors.secondary
                              : AppColors.onSurface,
                        ),
                        _InfoRow(
                          label: 'PROTO',
                          value: _transportLabel(
                            connectionState.transport,
                            isDemoMode: isDemoMode,
                          ),
                        ),
                        _InfoRow(
                          label: 'TARGET',
                          value: discoveredDevice?.name ?? 'Awaiting device',
                          valueColor: discoveredDevice != null
                              ? AppColors.primary
                              : AppColors.onSurface,
                        ),
                        _InfoRow(
                          label: 'ENDPOINT',
                          value: discoveredDevice != null
                              ? '${discoveredDevice.ip}:${discoveredDevice.port}'
                              : (connectionState.ipAddress ?? _defaultIp),
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
                                  connectionMessage,
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
                  if (!isDemoMode) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isScanning ? null : () => _runMdnsScan(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Rescan'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _isScanning || isBusy ? null : _handlePrimaryAction,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.surfaceDim,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _primaryButtonLabel(isDemoMode),
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
                    discoveredDevice != null
                        ? 'Reference ID: ${discoveredDevice.name.toUpperCase()}'
                        : 'Reference ID: OM-772-CNX',
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.monoSmall.copyWith(
                color: valueColor ?? AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
