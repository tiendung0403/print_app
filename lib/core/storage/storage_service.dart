import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class StorageService {
  static const String keyIp = 'printer_ip';
  static const String keyPort = 'printer_port';
  static const String keyPaperSize = 'printer_paper_size'; // '58' or '80'

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  String get ipAddress => _prefs.getString(keyIp) ?? '10.26.12.16';
  
  Future<void> setIpAddress(String ip) async {
    await _prefs.setString(keyIp, ip);
  }

  int get port => _prefs.getInt(keyPort) ?? 9100;

  Future<void> setPort(int port) async {
    await _prefs.setInt(keyPort, port);
  }

  String get paperSize => _prefs.getString(keyPaperSize) ?? '80';

  Future<void> setPaperSize(String size) async {
    await _prefs.setString(keyPaperSize, size);
  }

  static const String keyEnableRounding = 'enable_rounding';
  static const String keyDarkMode = 'dark_mode';

  bool get enableRounding => _prefs.getBool(keyEnableRounding) ?? true;

  Future<void> setEnableRounding(bool value) async {
    await _prefs.setBool(keyEnableRounding, value);
  }

  bool get isDarkMode => _prefs.getBool(keyDarkMode) ?? false;
  
  late final themeModeNotifier = ValueNotifier<ThemeMode>(
    isDarkMode ? ThemeMode.dark : ThemeMode.light
  );

  Future<void> toggleDarkMode(bool value) async {
    await _prefs.setBool(keyDarkMode, value);
    themeModeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }
}
