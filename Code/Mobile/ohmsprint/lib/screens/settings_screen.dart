import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/connection_state.dart';
import '../core/models/settings_model.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../providers/connection_provider.dart';
import '../providers/demo_mode_provider.dart';
import '../providers/measurement_provider.dart';
import '../providers/power_events_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/metric_label.dart';

const Map<int, String> _updateIntervalOptions = {
  500: '0.5s',
  1000: '1s',
  2000: '2s',
  5000: '5s',
};

TextInputFormatter _decimalInputFormatter(int maxDecimals) {
  final pattern = RegExp('^\\d*\\.?\\d{0,$maxDecimals}\$');
  return TextInputFormatter.withFunction((oldValue, newValue) {
    return pattern.hasMatch(newValue.text) ? newValue : oldValue;
  });
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _deviceIpController = TextEditingController();
  final _tariffController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _pfController = TextEditingController();

  final _deviceIpFocusNode = FocusNode();
  final _tariffFocusNode = FocusNode();
  final _frequencyFocusNode = FocusNode();
  final _pfFocusNode = FocusNode();

  static final _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;

  double? _pendingVoltageThreshold;
  String? _notificationPermissionHint;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _deviceIpController.text = settings.deviceIp;
    _tariffController.text = settings.tariffPrice == 0
        ? '0.00'
        : settings.tariffPrice.toStringAsFixed(2);
    _frequencyController.text = settings.freqThreshold.toStringAsFixed(1);
    _pfController.text = settings.pfThreshold.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _deviceIpController.dispose();
    _tariffController.dispose();
    _frequencyController.dispose();
    _pfController.dispose();
    _deviceIpFocusNode.dispose();
    _tariffFocusNode.dispose();
    _frequencyFocusNode.dispose();
    _pfFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final connectionState = ref.watch(connectionProvider);
    final isDemoMode = ref.watch(demoModeProvider);
    final voltageThreshold =
        _pendingVoltageThreshold ?? settings.voltageThreshold.clamp(1, 20);

    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Configuration',
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 32,
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SYSTEM PARAMETER CONTROL',
                style: AppTypography.monoSmall.copyWith(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.72),
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 28),
              _SettingsSection(
                icon: Icons.router_rounded,
                iconColor: AppColors.primary,
                title: 'Device Connection',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SettingLabel('IP Address'),
                    const SizedBox(height: 8),
                    _SettingsTextField(
                      controller: _deviceIpController,
                      focusNode: _deviceIpFocusNode,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveDeviceIp(),
                      onTapOutside: (_) => _saveDeviceIp(),
                    ),
                    const SizedBox(height: 18),
                    _SwitchRow(
                      title: 'Auto-connect',
                      subtitle: 'Reconnect on startup',
                      value: settings.autoConnect,
                      onChanged: settingsNotifier.setAutoConnect,
                    ),
                    const SizedBox(height: 18),
                    _ReadOnlyInfoRow(
                      label: 'WiFi Name',
                      value: _wifiName(
                        connectionState: connectionState,
                        isDemoMode: isDemoMode,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                icon: Icons.payments_rounded,
                iconColor: AppColors.secondary,
                title: 'Tariff Configuration',
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SettingLabel('Price / kWh'),
                          const SizedBox(height: 8),
                          _SettingsTextField(
                            controller: _tariffController,
                            focusNode: _tariffFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              _decimalInputFormatter(2),
                            ],
                            onSubmitted: (_) => _saveTariffPrice(),
                            onTapOutside: (_) => _saveTariffPrice(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SettingLabel('Currency'),
                          const SizedBox(height: 8),
                          _SettingsDropdown<Currency>(
                            value: settings.currency,
                            items: const [
                              DropdownMenuItem(
                                value: Currency.rsd,
                                child: Text('RSD'),
                              ),
                              DropdownMenuItem(
                                value: Currency.eur,
                                child: Text('EUR'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                settingsNotifier.setCurrency(value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                icon: Icons.notification_important_rounded,
                iconColor: AppColors.error,
                title: 'Safety Thresholds',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _SettingLabel('Voltage Alert Band'),
                        ),
                        Text(
                          '${voltageThreshold.toStringAsFixed(0)}%',
                          style: AppTypography.monoSmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.error,
                        inactiveTrackColor:
                            AppColors.surfaceContainerHigh.withValues(
                          alpha: 0.8,
                        ),
                        thumbColor: AppColors.error,
                        overlayColor: AppColors.error.withValues(alpha: 0.12),
                      ),
                      child: Slider(
                        min: 1,
                        max: 20,
                        divisions: 19,
                        value: voltageThreshold,
                        onChanged: (value) {
                          setState(() => _pendingVoltageThreshold = value);
                        },
                        onChangeEnd: (value) async {
                          setState(() => _pendingVoltageThreshold = null);
                          if (value != settings.voltageThreshold) {
                            await settingsNotifier.setVoltageThreshold(value);
                          }
                        },
                      ),
                    ),
                    Text(
                      'Allowed deviation from nominal 230V before alerting.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _SettingLabel('Freq Threshold (Hz)'),
                              const SizedBox(height: 8),
                              _SettingsTextField(
                                controller: _frequencyController,
                                focusNode: _frequencyFocusNode,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  _decimalInputFormatter(2),
                                ],
                                onSubmitted: (_) => _saveFrequencyThreshold(),
                                onTapOutside: (_) => _saveFrequencyThreshold(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _SettingLabel('PF Threshold'),
                              const SizedBox(height: 8),
                              _SettingsTextField(
                                controller: _pfController,
                                focusNode: _pfFocusNode,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  _decimalInputFormatter(2),
                                ],
                                onSubmitted: (_) => _savePfThreshold(),
                                onTapOutside: (_) => _savePfThreshold(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SwitchRow(
                      title: 'Enable Push Notifications',
                      subtitle: 'Request permission before enabling alerts',
                      value: settings.notificationsEnabled,
                      onChanged: _updateNotificationsEnabled,
                    ),
                    if (_notificationPermissionHint != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _notificationPermissionHint!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                icon: Icons.palette_rounded,
                iconColor: AppColors.tertiary,
                title: 'Display',
                child: Column(
                  children: [
                    _SwitchRow(
                      title: 'Dark Theme',
                      subtitle: 'Switch between light and dark surfaces',
                      value: settings.darkMode,
                      onChanged: settingsNotifier.setDarkMode,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: _SettingLabel('Update Interval'),
                        ),
                        SizedBox(
                          width: 132,
                          child: _SettingsDropdown<int>(
                            value: settings.updateInterval,
                            items: _updateIntervalOptions.entries
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                settingsNotifier.setUpdateInterval(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (kDebugMode) ...[
                _SettingsSection(
                  icon: Icons.developer_mode_rounded,
                  iconColor: AppColors.primary,
                  title: 'Developer',
                  child: _SwitchRow(
                    title: 'Demo Mode',
                    subtitle:
                        'Use mock telemetry stream instead of device data',
                    value: isDemoMode,
                    onChanged: (value) {
                      ref.read(demoModeProvider.notifier).state = value;
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _SettingsSection(
                icon: Icons.storage_rounded,
                iconColor: AppColors.onSurfaceVariant,
                title: 'Data Management',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.push('/settings/export'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.surfaceDim,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Export Data'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _confirmClearLocalData,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Clear Local Data'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'OhmSprint v0.1.0',
                      style: AppTypography.headlineMedium.copyWith(
                        fontSize: 22,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'OhmSprint 2026',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDeviceIp() async {
    final nextValue = _deviceIpController.text.trim();
    if (nextValue == ref.read(settingsProvider).deviceIp) {
      return;
    }
    if (!_isValidDeviceEndpoint(nextValue)) {
      _showSnackBar('Enter a valid IPv4 address or ws:// endpoint.');
      return;
    }

    await ref.read(settingsProvider.notifier).setDeviceIp(nextValue);
  }

  Future<void> _saveTariffPrice() async {
    final parsedValue = double.tryParse(_tariffController.text.trim());
    if (parsedValue == null || parsedValue < 0) {
      _showSnackBar('Enter a valid tariff price.');
      return;
    }
    if (parsedValue == ref.read(settingsProvider).tariffPrice) {
      return;
    }

    await ref.read(settingsProvider.notifier).setTariffPrice(parsedValue);
  }

  Future<void> _saveFrequencyThreshold() async {
    final parsedValue = double.tryParse(_frequencyController.text.trim());
    if (parsedValue == null || parsedValue <= 0) {
      _showSnackBar('Enter a valid frequency threshold.');
      return;
    }
    if (parsedValue == ref.read(settingsProvider).freqThreshold) {
      return;
    }

    await ref.read(settingsProvider.notifier).setFreqThreshold(parsedValue);
  }

  Future<void> _savePfThreshold() async {
    final parsedValue = double.tryParse(_pfController.text.trim());
    if (parsedValue == null || parsedValue < 0 || parsedValue > 1) {
      _showSnackBar('Power factor threshold must be between 0.0 and 1.0.');
      return;
    }
    if (parsedValue == ref.read(settingsProvider).pfThreshold) {
      return;
    }

    await ref.read(settingsProvider.notifier).setPfThreshold(parsedValue);
  }

  Future<void> _updateNotificationsEnabled(bool value) async {
    if (!value) {
      setState(() => _notificationPermissionHint = null);
      await ref.read(settingsProvider.notifier).setNotificationsEnabled(false);
      return;
    }

    final granted = await _requestNotificationPermission();
    if (!granted) {
      if (!mounted) {
        return;
      }

      setState(() {
        _notificationPermissionHint =
            'Notification permission was denied or is unavailable in this preview build.';
      });
      _showSnackBar('Notification permission was not granted.');
      await ref.read(settingsProvider.notifier).setNotificationsEnabled(false);
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() => _notificationPermissionHint = null);
    await ref.read(settingsProvider.notifier).setNotificationsEnabled(true);
  }

  Future<bool> _requestNotificationPermission() async {
    if (kIsWeb) {
      return false;
    }

    if (!_notificationsInitialized) {
      try {
        await _notificationsPlugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
            macOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        );
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Notification init failed: $error');
        }
        return false;
      }
      _notificationsInitialized = true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _notificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      case TargetPlatform.iOS:
        return await _notificationsPlugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(
                  alert: true,
                  badge: true,
                  sound: true,
                ) ??
            false;
      case TargetPlatform.macOS:
        return await _notificationsPlugin
                .resolvePlatformSpecificImplementation<
                    MacOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(
                  alert: true,
                  badge: true,
                  sound: true,
                ) ??
            false;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  Future<void> _confirmClearLocalData() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: Text(
            'Clear local data?',
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 20,
              color: AppColors.onSurface,
            ),
          ),
          content: Text(
            'This removes cached measurements and power quality events from the device.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.surfaceDim,
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldClear != true) {
      return;
    }

    try {
      await ref.read(measurementHistoryProvider.notifier).clearHistory();
      await ref.read(powerEventsProvider.notifier).clearEvents();
      if (!mounted) {
        return;
      }
      _showSnackBar('Local telemetry cache cleared.');
    } catch (_) {
      _showSnackBar('Could not clear local data right now.');
    }
  }

  String _wifiName({
    required DeviceConnectionState connectionState,
    required bool isDemoMode,
  }) {
    if (isDemoMode) {
      return 'Demo Telemetry Link';
    }

    if ((connectionState.ipAddress ?? '').isNotEmpty) {
      return 'ESP32-C3 Local AP';
    }

    return 'Awaiting device info';
  }

  bool _isValidDeviceEndpoint(String value) {
    if (value.isEmpty) {
      return false;
    }

    final ipPattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (ipPattern.hasMatch(value)) {
      return value.split('.').every((segment) {
        final parsed = int.tryParse(segment);
        return parsed != null && parsed >= 0 && parsed <= 255;
      });
    }

    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'ws' || uri.scheme == 'wss') &&
        uri.host.isNotEmpty;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceContainerHigh,
        content: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: AppTypography.monoSmall.copyWith(
                color: iconColor.withValues(alpha: 0.82),
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: child,
        ),
      ],
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.bodyMedium.copyWith(
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.onTapOutside,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String) onSubmitted;
  final TapRegionCallback? onTapOutside;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      style: AppTypography.monoSmall.copyWith(
        color: AppColors.onSurface,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.55),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.45),
          ),
        ),
      ),
      onSubmitted: onSubmitted,
      onTapOutside: onTapOutside,
    );
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      dropdownColor: AppColors.surfaceContainer,
      iconEnabledColor: AppColors.primary,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.55),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      style: AppTypography.monoSmall.copyWith(
        color: AppColors.onSurface,
        fontSize: 14,
      ),
      onChanged: onChanged,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: value,
          activeColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ReadOnlyInfoRow extends StatelessWidget {
  const _ReadOnlyInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MetricLabel(label),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.monoSmall.copyWith(
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
