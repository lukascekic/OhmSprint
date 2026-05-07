import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

final demoModeProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((settings) => settings.demoMode));
});
