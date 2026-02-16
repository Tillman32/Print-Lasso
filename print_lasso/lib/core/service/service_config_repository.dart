import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'service_config.dart';

class ServiceConfigRepository {
  const ServiceConfigRepository();

  static const String _serviceConfigKey = 'print_lasso_service_config_v1';

  Future<ServiceConfig?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? rawJson = prefs.getString(_serviceConfigKey);
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(rawJson) as Map<String, dynamic>;
      return ServiceConfig.fromJson(decoded);
    } catch (_) {
      await prefs.remove(_serviceConfigKey);
      return null;
    }
  }

  Future<void> save(ServiceConfig config) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serviceConfigKey, jsonEncode(config.toJson()));
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serviceConfigKey);
  }
}
