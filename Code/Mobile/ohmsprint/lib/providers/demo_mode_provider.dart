import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final demoModeProvider = StateProvider<bool>((ref) => kDebugMode);
