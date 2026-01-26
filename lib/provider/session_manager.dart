import 'dart:convert';
import 'dart:html' as html; // WEB ONLY

class SessionManager {
  static const String _kLoggedIn = 'isLoggedIn';
  static const String _kRole = 'role';
  static const String _kUserData = 'userData';
  static const String _kCurrentTab = 'currentTab';
  static const String _kSelectedDevice = 'selectedDevice';
  static const String _kCurrentStep = 'currentStep'; // 🆕 NEW: Key for Config Step

  // --- EXISTING AUTH METHODS ---
  static void saveSession(String role, Map<String, dynamic> userData) {
    html.window.sessionStorage[_kLoggedIn] = 'true';
    html.window.sessionStorage[_kRole] = role;
    html.window.sessionStorage[_kUserData] = jsonEncode(userData);
  }

  static void clearSession() {
    html.window.sessionStorage.clear();
  }

  static bool hasSession() {
    return html.window.sessionStorage[_kLoggedIn] == 'true';
  }

  static String? getRole() {
    return html.window.sessionStorage[_kRole];
  }

  static Map<String, dynamic> getUserData() {
    final data = html.window.sessionStorage[_kUserData];
    if (data != null) return jsonDecode(data);
    return {};
  }

  // --- TAB METHODS ---
  static void saveCurrentTab(String tabName) {
    html.window.sessionStorage[_kCurrentTab] = tabName;
  }

  static String getSavedTab() {
    return html.window.sessionStorage[_kCurrentTab] ?? '';
  }

  // --- DEVICE PERSISTENCE METHODS ---
  static void saveSelectedDevice(Map<String, dynamic> deviceData) {
    html.window.sessionStorage[_kSelectedDevice] = jsonEncode(deviceData);
  }

  static Map<String, dynamic>? getSelectedDevice() {
    final data = html.window.sessionStorage[_kSelectedDevice];
    if (data != null && data.isNotEmpty) {
      try {
        return jsonDecode(data);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // --- 🆕 NEW: STEP PERSISTENCE METHODS ---
  static void saveCurrentStep(String stepName) {
    html.window.sessionStorage[_kCurrentStep] = stepName;
  }

  static String getSavedStep() {
    return html.window.sessionStorage[_kCurrentStep] ?? '';
  }
}