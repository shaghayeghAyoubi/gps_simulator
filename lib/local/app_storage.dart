import 'package:shared_preferences/shared_preferences.dart';
import 'package:gps_simulator/constants.dart';

part 'storage_keys.dart';

class AppStorage {

  // Save IP address
  static Future<void> saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_StorageKeys.ipMqtt, ip);
  }

  // Get IP address
  static Future<String> getIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_StorageKeys.ipMqtt) ?? AppConstants.defaultIp;
  }

  // Save Port
  static Future<void> savePort(String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_StorageKeys.portMqtt, port);
  }

  // Get Port
  static Future<String> getPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_StorageKeys.portMqtt) ?? AppConstants.defaultPort;
  }

  // Save Topic
  static Future<void> saveTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_StorageKeys.topicMqtt, topic);
  }

  // Get Topic
  static Future<String> getTopic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_StorageKeys.topicMqtt) ?? AppConstants.defaultTopic;
  }

  // Get all settings at once
  static Future<Map<String, String>> getAllSettings() async {
    return {
      'ip': await getIp(),
      'port': await getPort(),
      'topic': await getTopic(),
    };
  }

  // Clear all MQTT settings
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_StorageKeys.portMqtt);
    await prefs.remove(_StorageKeys.ipMqtt);
    await prefs.remove(_StorageKeys.topicMqtt);
  }

  // Clear specific setting
  static Future<void> clearSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}