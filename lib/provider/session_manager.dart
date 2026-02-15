import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _kLoggedIn = 'isLoggedIn';
  static const String _kRole = 'role';
  static const String _kUserData = 'userData';
  static const String _kCurrentTab = 'currentTab';
  static const String _kSelectedDevice = 'selectedDevice';
  static const String _kCurrentStep = 'currentStep';

  // Helper to get preferences instance
  static Future<SharedPreferences> _getPrefs() async => await SharedPreferences.getInstance();

  // --- AUTH METHODS ---
  static Future<void> saveSession(String role, Map<String, dynamic> userData) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_kLoggedIn, true);
    await prefs.setString(_kRole, role);
    await prefs.setString(_kUserData, jsonEncode(userData));
  }

  static Future<void> clearSession() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }

  static Future<bool> hasSession() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_kLoggedIn) ?? false;
  }

  static Future<String?> getRole() async {
    final prefs = await _getPrefs();
    return prefs.getString(_kRole);
  }

  static Future<Map<String, dynamic>> getUserData() async {
    final prefs = await _getPrefs();
    final data = prefs.getString(_kUserData);
    if (data != null) return jsonDecode(data);
    return {};
  }

  // --- TAB METHODS ---
  static Future<void> saveCurrentTab(String tabName) async {
    final prefs = await _getPrefs();
    await prefs.setString(_kCurrentTab, tabName);
  }

  static Future<String> getSavedTab() async {
    final prefs = await _getPrefs();
    return prefs.getString(_kCurrentTab) ?? '';
  }

  // --- DEVICE PERSISTENCE METHODS ---
  static Future<void> saveSelectedDevice(Map<String, dynamic> deviceData) async {
    final prefs = await _getPrefs();
    await prefs.setString(_kSelectedDevice, jsonEncode(deviceData));
  }

  static Future<Map<String, dynamic>?> getSelectedDevice() async {
    final prefs = await _getPrefs();
    final data = prefs.getString(_kSelectedDevice);
    if (data != null && data.isNotEmpty) {
      try {
        return jsonDecode(data);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // --- STEP PERSISTENCE METHODS ---
  static Future<void> saveCurrentStep(String stepName) async {
    final prefs = await _getPrefs();
    await prefs.setString(_kCurrentStep, stepName);
  }

  static Future<String> getSavedStep() async {
    final prefs = await _getPrefs();
    return prefs.getString(_kCurrentStep) ?? '';
  }
}