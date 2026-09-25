import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress.dart';

/// Persists [Progress] as JSON in shared preferences.
class SaveRepository {
  static const _key = 'progress_v1';

  Future<Progress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const Progress();
    try {
      return Progress.decode(raw);
    } on FormatException catch (e) {
      // A corrupt save must not brick the game; start fresh instead.
      debugPrint('Discarding unreadable save: $e');
      return const Progress();
    }
  }

  Future<void> save(Progress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, progress.encode());
  }
}
