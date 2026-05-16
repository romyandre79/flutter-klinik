import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _keyToken = 'auth_token';
  static const String _keyUsername = 'username';
  static const String _keyPassword = 'cached_password'; // For background sync login
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'userId';
  static const String _keyRole = 'role';
  static const String _keyName = 'name';
  static const String _keyBaseUrl = 'server_base_url';

  static SessionService? _instance;
  final SharedPreferences _prefs;

  SessionService._(this._prefs);

  static Future<SessionService> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = SessionService._(prefs);
    }
    return _instance!;
  }

  Future<void> saveSession({
    required int userId,
    required String username,
    required String role,
    required String name,
    String? token,
    String? password,
  }) async {
    await _prefs.setInt(_keyUserId, userId);
    await _prefs.setString(_keyUsername, username);
    await _prefs.setString(_keyRole, role);
    await _prefs.setString(_keyName, name);
    if (token != null) {
      await _prefs.setString(_keyToken, token);
    }
    if (password != null) {
      await _prefs.setString(_keyPassword, password);
    }
    await _prefs.setBool(_keyIsLoggedIn, true);
  }

  String? getToken() => _prefs.getString(_keyToken);
  String? getUsername() => _prefs.getString(_keyUsername);
  String? getCachedPassword() => _prefs.getString(_keyPassword);
  int? getUserId() => _prefs.getInt(_keyUserId);
  String? getRole() => _prefs.getString(_keyRole);
  String? getName() => _prefs.getString(_keyName);
  bool isLoggedIn() => _prefs.getBool(_keyIsLoggedIn) ?? false;

  Future<void> clearSession() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyPassword);
    await _prefs.setBool(_keyIsLoggedIn, false);
  }

  bool hasCachedCredentials() {
    return getUsername() != null && getCachedPassword() != null;
  }

  Future<void> setBaseUrl(String url) async {
    await _prefs.setString(_keyBaseUrl, url);
  }

  String? getBaseUrl() => _prefs.getString(_keyBaseUrl);
}
