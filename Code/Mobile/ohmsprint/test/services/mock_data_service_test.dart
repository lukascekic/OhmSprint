import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsprint/services/mock_data_service.dart';

void main() {
  test('emits measurement-compatible json within valid ranges', () async {
    final service = MockDataService();

    addTearDown(service.dispose);

    final reading = await service
        .start(interval: const Duration(milliseconds: 10))
        .firstWhere((payload) => !payload.containsKey('ev'));

    expect(reading['v'], isA<double>());
    expect(reading['v'] as double, inInclusiveRange(200.0, 260.0));
    expect(reading['i'] as double, inInclusiveRange(0.0, 20.0));
    expect(reading['f'] as double, inInclusiveRange(49.0, 51.0));
    expect(reading['pf'] as double, inInclusiveRange(-1.0, 1.0));
    expect(reading['t'], isA<int>());
  });
}
