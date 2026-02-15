import 'package:countron_app/provider/session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceSetupStep {
  deviceSelection,
  wifiConfiguration,
  channelConfiguration,
}

class ClientProvider extends ChangeNotifier {
  // --- EXISTING STATE ---
  DeviceSetupStep _currentStep = DeviceSetupStep.deviceSelection;
  Map<String, dynamic>? _selectedDeviceData;

  // [CRITICAL] This variable holds the "OldRecNo" (Current Database ID)
  // untill the API update is successful. Then it becomes the "NewRecNo".
  int? _selectedDeviceRecNo;

  List<dynamic> _channels = [];

  // --- NEW: USER/CLIENT DATA STATE ---
  Map<String, dynamic>? _clientData;

  // --- GETTERS ---
  DeviceSetupStep get currentStep => _currentStep;
  Map<String, dynamic>? get selectedDeviceData => _selectedDeviceData;
  int? get selectedDeviceRecNo => _selectedDeviceRecNo;
  List<dynamic> get channels => _channels;

  String get selectedDeviceLocation {
    if (_selectedDeviceData == null) return 'Unknown';
    return _selectedDeviceData!['Location'] ?? 'India';
  }

  Map<String, dynamic>? get clientData => _clientData;

  // =========================================================
  //                 CORE ID MANAGEMENT LOGIC
  // =========================================================

  /// [ACTION: UPDATE ID SUCCESSFUL]
  /// Call this ONLY after the API successfully updates the Device ID in the database.
  ///
  /// FLOW:
  /// 1. Old ID was: _selectedDeviceRecNo (sent to API as OldRecNo)
  /// 2. API Success returns.
  /// 3. Call this method with the [newId] (received from Hardware).
  /// 4. This method overwrites the Old ID with the New ID everywhere.
  Future<void> updateAfterHardwareSync(int newId) async {
    debugPrint("PROVIDER: Overwriting Old Device ID ($_selectedDeviceRecNo) with New ID ($newId)");

    // 1. Update the integer state
    _selectedDeviceRecNo = newId;

    // 2. Update the Map Data (so UI text fields update automatically)
    if (_selectedDeviceData != null) {
      _selectedDeviceData!['DeviceID'] = newId.toString();
    }

    // 3. Persist to SharedPreferences (Crucial for next restart/wifi scan)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_device_recno', newId);

    // 4. Update Session Manager (So app restart remembers new ID)
    if (_selectedDeviceData != null) {
      SessionManager.saveSelectedDevice(_selectedDeviceData!);
    }

    notifyListeners();
  }

  // =========================================================
  //                 SELECTION & RESTORATION
  // =========================================================

  void setClientData(Map<String, dynamic> data) {
    _clientData = data;
    _currentStep = DeviceSetupStep.wifiConfiguration;
    notifyListeners();
  }

  Future<void> setSelectedDevice(int recNo, Map<String, dynamic> deviceData) async {
    _selectedDeviceData = deviceData;

    // Prefer parsing DeviceID from map if valid, otherwise use passed recNo
    if (deviceData.containsKey('DeviceID')) {
      final idValue = deviceData['DeviceID'];
      _selectedDeviceRecNo = (idValue is String) ? int.tryParse(idValue) : idValue as int?;
    } else {
      _selectedDeviceRecNo = recNo;
    }

    // [FIX] Save to SharedPreferences immediately so WifiSetupWidget can find "OldRecNo"
    if (_selectedDeviceRecNo != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_device_recno', _selectedDeviceRecNo!);
    }

    _currentStep = DeviceSetupStep.wifiConfiguration;
    notifyListeners();
  }

  void updateLocalProfile({
    String? displayName,
    String? email,
    String? address,
    String? logoPath,
  }) {
    if (_clientData != null) {
      if (displayName != null) _clientData!['DisplayName'] = displayName;
      if (email != null) _clientData!['ContactEmail'] = email;
      if (address != null) _clientData!['CompanyAddress'] = address;
      if (logoPath != null) _clientData!['LogoPath'] = logoPath;
      notifyListeners();
    }
  }

  // Save device AND reset step to selection
  Future<void> selectDevice(Map<String, dynamic> device) async {
    _selectedDeviceData = device;

    final idValue = device['DeviceID'];
    _selectedDeviceRecNo = (idValue is String) ? int.tryParse(idValue) : idValue as int?;

    _currentStep = DeviceSetupStep.deviceSelection;

    // SAVE TO SESSION
    SessionManager.saveSelectedDevice(device);
    SessionManager.saveCurrentStep('deviceSelection');

    // [FIX] Save to SharedPreferences immediately
    if (_selectedDeviceRecNo != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_device_recno', _selectedDeviceRecNo!);
    }

    notifyListeners();
  }

  // Restore Device AND Step from Session
  Future<void> restoreDevice(Map<String, dynamic> device) async {
    _selectedDeviceData = device;

    final idValue = device['DeviceID'];
    _selectedDeviceRecNo = (idValue is String) ? int.tryParse(idValue) : idValue as int?;

    // [FIX] Restore to SharedPreferences immediately
    if (_selectedDeviceRecNo != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_device_recno', _selectedDeviceRecNo!);
    }

    // Restore the Step
    final savedStep = SessionManager.getSavedStep();
    if (savedStep == 'channelConfiguration') {
      _currentStep = DeviceSetupStep.channelConfiguration;
    } else if (savedStep == 'wifiConfiguration') {
      _currentStep = DeviceSetupStep.wifiConfiguration;
    } else {
      _currentStep = DeviceSetupStep.deviceSelection;
    }

    notifyListeners();
  }

  void goToChannelConfiguration() {
    _currentStep = DeviceSetupStep.channelConfiguration;
    SessionManager.saveCurrentStep('channelConfiguration');
    notifyListeners();
  }

  void goToWifiConfiguration() {
    _currentStep = DeviceSetupStep.wifiConfiguration;
    SessionManager.saveCurrentStep('wifiConfiguration');
    notifyListeners();
  }

  void goToDeviceOverview() {
    _currentStep = DeviceSetupStep.deviceSelection;
    SessionManager.saveCurrentStep('deviceSelection');
    notifyListeners();
  }

  Future<void> clearSelection() async {
    _currentStep = DeviceSetupStep.deviceSelection;
    _selectedDeviceData = null;
    _selectedDeviceRecNo = null;
    _channels = [];

    SessionManager.saveSelectedDevice({});
    SessionManager.saveCurrentStep('');

    // Clear Prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_device_recno');

    notifyListeners();
  }

  void setChannels(List<dynamic> channels) {
    _channels = channels;
    notifyListeners();
  }

  Future<void> clearData() async {
    _clientData = null;
    _selectedDeviceData = null;
    _selectedDeviceRecNo = null;
    _channels = [];
    _currentStep = DeviceSetupStep.deviceSelection;

    SessionManager.saveSelectedDevice({});
    SessionManager.saveCurrentStep('');

    // Clear Prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_device_recno');

    notifyListeners();
  }
}