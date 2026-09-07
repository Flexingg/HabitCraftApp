import 'package:shared_preferences/shared_preferences.dart';

/// Persisted connection settings (bridge URL + API key). Editable in the app.
class AppConfig {
  static const defaultBase = 'http://192.168.1.146:9171';
  static const defaultKey = 'habitcraft-dev-key';

  String baseUrl;
  String apiKey;

  AppConfig({String? baseUrl, String? apiKey})
      : baseUrl = baseUrl ?? defaultBase,
        apiKey = apiKey ?? defaultKey;

  static Future<AppConfig> load() async {
    final sp = await SharedPreferences.getInstance();
    return AppConfig(
      baseUrl: sp.getString('hc_base') ?? defaultBase,
      apiKey: sp.getString('hc_key') ?? defaultKey,
    );
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('hc_base', baseUrl);
    await sp.setString('hc_key', apiKey);
  }
}
