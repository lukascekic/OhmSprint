enum Currency { rsd, eur }

class SettingsModel {
  const SettingsModel({
    this.deviceIp = '192.168.4.1',
    this.autoConnect = true,
    this.tariffPrice = 0,
    this.currency = Currency.rsd,
    this.voltageThreshold = 10,
    this.freqThreshold = 0.5,
    this.pfThreshold = 0.8,
    this.notificationsEnabled = false,
    this.darkMode = true,
    this.updateInterval = 1000,
  })  : assert(tariffPrice >= 0),
        assert(voltageThreshold >= 0),
        assert(freqThreshold >= 0),
        assert(pfThreshold >= 0 && pfThreshold <= 1),
        assert(updateInterval > 0);

  final String deviceIp;
  final bool autoConnect;
  final double tariffPrice;
  final Currency currency;
  final double voltageThreshold;
  final double freqThreshold;
  final double pfThreshold;
  final bool notificationsEnabled;
  final bool darkMode;
  final int updateInterval;

  SettingsModel copyWith({
    String? deviceIp,
    bool? autoConnect,
    double? tariffPrice,
    Currency? currency,
    double? voltageThreshold,
    double? freqThreshold,
    double? pfThreshold,
    bool? notificationsEnabled,
    bool? darkMode,
    int? updateInterval,
  }) {
    return SettingsModel(
      deviceIp: deviceIp ?? this.deviceIp,
      autoConnect: autoConnect ?? this.autoConnect,
      tariffPrice: tariffPrice ?? this.tariffPrice,
      currency: currency ?? this.currency,
      voltageThreshold: voltageThreshold ?? this.voltageThreshold,
      freqThreshold: freqThreshold ?? this.freqThreshold,
      pfThreshold: pfThreshold ?? this.pfThreshold,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
      updateInterval: updateInterval ?? this.updateInterval,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceIp': deviceIp,
      'autoConnect': autoConnect,
      'tariffPrice': tariffPrice,
      'currency': currency.name,
      'voltageThreshold': voltageThreshold,
      'freqThreshold': freqThreshold,
      'pfThreshold': pfThreshold,
      'notificationsEnabled': notificationsEnabled,
      'darkMode': darkMode,
      'updateInterval': updateInterval,
    };
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      deviceIp: json['deviceIp'] as String? ?? '192.168.4.1',
      autoConnect: json['autoConnect'] as bool? ?? true,
      tariffPrice: (json['tariffPrice'] as num?)?.toDouble() ?? 0,
      currency: Currency.values.firstWhere(
        (value) => value.name == json['currency'],
        orElse: () => Currency.rsd,
      ),
      voltageThreshold: (json['voltageThreshold'] as num?)?.toDouble() ?? 10,
      freqThreshold: (json['freqThreshold'] as num?)?.toDouble() ?? 0.5,
      pfThreshold: (json['pfThreshold'] as num?)?.toDouble() ?? 0.8,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      darkMode: json['darkMode'] as bool? ?? true,
      updateInterval: (json['updateInterval'] as num?)?.toInt() ?? 1000,
    );
  }
}
