import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedCityProvider = StateProvider<String?>((ref) => null);
final showRegisterPopupProvider = StateProvider<bool>((ref) => true);
