import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/station_search.dart';

/// The last few station searches, newest first, kept on the device so the
/// search page can offer them again like a maps app does.
class RecentSearches {
  static const _key = 'recent_station_searches';

  final Future<SharedPreferences> Function() _prefs;

  RecentSearches({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  Future<List<String>> load() async {
    try {
      final prefs = await _prefs();
      return prefs.getStringList(_key) ?? const [];
    } on Exception catch (e) {
      debugPrint('Recent searches unavailable: $e');
      return const [];
    }
  }

  /// Records [query] and returns the updated list.
  Future<List<String>> add(String query) async {
    final next = pushRecentSearch(await load(), query);
    await _save(next);
    return next;
  }

  /// Forgets [query] and returns the updated list.
  Future<List<String>> remove(String query) async {
    final next = [
      for (final q in await load())
        if (q != query) q,
    ];
    await _save(next);
    return next;
  }

  Future<void> _save(List<String> queries) async {
    try {
      final prefs = await _prefs();
      await prefs.setStringList(_key, queries);
    } on Exception catch (e) {
      debugPrint('Could not save recent searches: $e');
    }
  }
}
