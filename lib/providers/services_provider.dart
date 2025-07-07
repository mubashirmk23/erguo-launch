import 'package:flutter_riverpod/flutter_riverpod.dart';

final serviceIconsProvider = Provider<Map<String, String>>((ref) {
  return {
    "Plumbing": "assets/icons/plumbing.png",
    "Electrical Work": "assets/icons/electrical.png",
    "Garden Work": "assets/icons/garden.png",
    "Wooden Work": "assets/icons/woodwork.png",
    "STP": "assets/icons/stp.png",
    "AC Service": "assets/icons/ac_service.png",
  };
});
