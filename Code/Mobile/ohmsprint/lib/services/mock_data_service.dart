import 'dart:async';
import 'dart:math';

class MockDataService {
  MockDataService({Random? random}) : _random = random ?? Random();

  final Random _random;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _timer;
  double _voltage = 230;
  double _current = 4;
  double _currentN = 3.9;
  double _frequency = 50;
  double _powerFactor = 0.97;
  double _importEnergy = 0;
  double _exportEnergy = 0;
  int _ticksUntilEvent = 45;
  Duration _sampleInterval = const Duration(seconds: 1);
  bool _isDisposed = false;

  Stream<Map<String, dynamic>> start({
    Duration interval = const Duration(seconds: 1),
  }) {
    if (_isDisposed) {
      throw StateError('MockDataService has been disposed');
    }

    if (_timer != null) {
      return _controller.stream;
    }

    _sampleInterval = interval;
    _emitMeasurement();
    _timer = Timer.periodic(interval, (_) {
      _emitMeasurement();
      _ticksUntilEvent -= 1;
      if (_ticksUntilEvent <= 0) {
        _controller.add(_buildEvent());
        _ticksUntilEvent = 30 + _random.nextInt(31);
      }
    });

    return _controller.stream;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _isDisposed = true;
    _controller.close();
  }

  void _emitMeasurement() {
    _voltage = _walk(_voltage, sigma: 2, min: 200, max: 260);
    _current = _walk(_current, sigma: 0.35, min: 0, max: 20);
    _currentN = _walk((_currentN + _current) / 2, sigma: 0.3, min: 0, max: 20);
    _frequency = _walk(_frequency, sigma: 0.02, min: 49, max: 51);
    _powerFactor = _walk(_powerFactor, sigma: 0.01, min: -1, max: 1);

    final apparentPower = _voltage * _current;
    final activePower = apparentPower * _powerFactor;
    final reactivePower = sqrt(
      max(0, (apparentPower * apparentPower) - (activePower * activePower)),
    );
    final intervalHours =
        _sampleInterval.inMilliseconds / Duration.millisecondsPerHour;
    if (activePower >= 0) {
      _importEnergy += (activePower / 1000) * intervalHours;
    } else {
      _exportEnergy += (activePower.abs() / 1000) * intervalHours;
    }

    _controller.add({
      'v': _voltage,
      'i': _current,
      'in': _currentN,
      'p': activePower,
      'q': reactivePower,
      's': apparentPower,
      'f': _frequency,
      'pf': _powerFactor,
      'ei': _importEnergy,
      'ee': _exportEnergy,
      't': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Map<String, dynamic> _buildEvent() {
    final eventType = ['sag', 'swell', 'freq', 'lpf'][_random.nextInt(4)];
    return switch (eventType) {
      'sag' => {
          'ev': 'sag',
          'v': _walk(_voltage - 15, sigma: 1.5, min: 180, max: 220),
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      'swell' => {
          'ev': 'swell',
          'v': _walk(_voltage + 15, sigma: 1.5, min: 240, max: 270),
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      'freq' => {
          'ev': 'freq',
          'f': _walk(_frequency - 0.4, sigma: 0.03, min: 48.8, max: 50.8),
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      _ => {
          'ev': 'lpf',
          'pf': _walk(_powerFactor - 0.2, sigma: 0.02, min: 0.4, max: 0.85),
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
    };
  }

  double _walk(
    double currentValue, {
    required double sigma,
    required double min,
    required double max,
  }) {
    final nextValue = currentValue + ((_random.nextDouble() * 2) - 1) * sigma;
    return nextValue.clamp(min, max);
  }
}
