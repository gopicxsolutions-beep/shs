import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/types.dart';

class AppState extends ChangeNotifier {
  AppUser user = defaultUser;
  Language language = Language.en;
  bool isAuthenticated = false;

  static const _roleKey = 'shg_role';
  static const _authKey = 'shg_authenticated';
  static const _langKey = 'shg_language';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final roleName = prefs.getString(_roleKey);
    if (roleName != null) {
      final match = Role.values.where((r) => r.name == roleName);
      if (match.isNotEmpty) user = user.copyWith(role: match.first);
    }
    final langName = prefs.getString(_langKey);
    if (langName != null) {
      final match = Language.values.where((l) => l.name == langName);
      if (match.isNotEmpty) language = match.first;
    }
    isAuthenticated = prefs.getBool(_authKey) ?? false;
    notifyListeners();
  }

  Future<void> setRole(Role role) async {
    user = user.copyWith(role: role);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.name);
  }

  Future<void> setLanguage(Language lang) async {
    language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang.name);
  }

  Future<void> setAuthenticated(bool v) async {
    isAuthenticated = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, v);
  }
}
