import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'providers/measurement_provider.dart';
import 'services/measurement_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Hive.initFlutter();

  final repository = MeasurementRepository();
  try {
    await repository.init();
  } catch (_) {
    await Hive.deleteBoxFromDisk(MeasurementRepository.measurementsBoxName);
    await Hive.deleteBoxFromDisk(MeasurementRepository.eventsBoxName);
    await Hive.deleteBoxFromDisk(MeasurementRepository.settingsBoxName);
    try {
      await repository.init();
    } catch (error) {
      runApp(_StartupErrorApp(error: '$error'));
      return;
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        measurementRepositoryProvider.overrideWithValue(repository),
      ],
      child: const OhmSprintApp(),
    ),
  );
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFF111125),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'OhmSprint failed to initialize local storage.\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFE2E0FC)),
              ),
            ),
          ),
        );
      },
    );
  }
}
