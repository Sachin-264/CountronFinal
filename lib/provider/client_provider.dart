import 'package:countron_app/provider/session_manager.dart';
import 'package:flutter/foundation.dart';

enum DeviceSetupStep {
  deviceSelection,
  wifiConfiguration,
  channelConfiguration,
}

class ClientProvider extends ChangeNotifier {
  // --- EXISTING STATE ---
  DeviceSetupStep _currentStep = DeviceSetupStep.deviceSelection;
  Map<String, dynamic>? _selectedDeviceData;
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

  // --- ACTIONS ---

  void setClientData(Map<String, dynamic> data) {
    _clientData = data;
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

  // Save device AND reset step to selection (default behavior)
  void selectDevice(Map<String, dynamic> device) {
    _selectedDeviceData = device;
    final idValue = device['DeviceID'];
    _selectedDeviceRecNo = (idValue is String) ? int.tryParse(idValue) : idValue as int?;

    _currentStep = DeviceSetupStep.deviceSelection;

    // SAVE TO SESSION
    SessionManager.saveSelectedDevice(device);
    SessionManager.saveCurrentStep('deviceSelection'); // Reset step in session

    notifyListeners();
  }

  // 🆕 UPDATED: Restore Device AND Step from Session
  void restoreDevice(Map<String, dynamic> device) {
    _selectedDeviceData = device;
    final idValue = device['DeviceID'];
    _selectedDeviceRecNo = (idValue is String) ? int.tryParse(idValue) : idValue as int?;

    // 1. Restore the Step from Session
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
    // 🆕 Save step
    SessionManager.saveCurrentStep('channelConfiguration');
    notifyListeners();
  }

  void goToWifiConfiguration() {
    _currentStep = DeviceSetupStep.wifiConfiguration;
    // 🆕 Save step
    SessionManager.saveCurrentStep('wifiConfiguration');
    notifyListeners();
  }

  // Optional: Method to go back to overview explicitly
  void goToDeviceOverview() {
    _currentStep = DeviceSetupStep.deviceSelection;
    SessionManager.saveCurrentStep('deviceSelection');
    notifyListeners();
  }

  void clearSelection() {
    _currentStep = DeviceSetupStep.deviceSelection;
    _selectedDeviceData = null;
    _selectedDeviceRecNo = null;
    _channels = [];

    // Clear Session
    SessionManager.saveSelectedDevice({});
    SessionManager.saveCurrentStep('');

    notifyListeners();
  }

  void setChannels(List<dynamic> channels) {
    _channels = channels;
    notifyListeners();
  }

  void clearData() {
    _clientData = null;
    _selectedDeviceData = null;
    _selectedDeviceRecNo = null;
    _channels = [];
    _currentStep = DeviceSetupStep.deviceSelection;

    SessionManager.saveSelectedDevice({});
    SessionManager.saveCurrentStep('');

    notifyListeners();
  }
}