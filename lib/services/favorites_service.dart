import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// المحطات المفضلة (محفوظة على الجهاز فقط).
class FavoritesService extends ChangeNotifier {
  FavoritesService._();
  static final FavoritesService instance = FavoritesService._();

  static const _key = 'favorite_station_ids';
  final Set<String> _ids = {};

  bool contains(String id) => _ids.contains(id);
  Set<String> get ids => Set.unmodifiable(_ids);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(prefs.getStringList(_key) ?? const <String>[]);
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.toList());
  }
}
