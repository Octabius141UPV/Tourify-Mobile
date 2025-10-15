import 'package:shared_preferences/shared_preferences.dart';

class LocalUserPrefs {
  static const String _displayNameKey = 'user_display_name';
  static const String _emailKey = 'user_email';
  static const String _photoUrlKey = 'user_photo_url';

  static Future<void> saveBasicProfile({
    String? displayName,
    String? email,
    String? photoURL,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (displayName != null) {
        await prefs.setString(_displayNameKey, displayName);
      }
      if (email != null) {
        await prefs.setString(_emailKey, email);
      }
      if (photoURL != null) {
        await prefs.setString(_photoUrlKey, photoURL);
      }
    } catch (_) {}
  }

  static Future<String?> getDisplayName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_displayNameKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_displayNameKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_photoUrlKey);
    } catch (_) {}
  }
}

