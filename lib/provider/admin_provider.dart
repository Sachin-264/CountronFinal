import 'package:flutter/material.dart';

class AdminProvider with ChangeNotifier {
  int? _adminRecNo;
  String _adminName = 'Admin';
  String _email = 'admin@example.com';
  String _username = '';

  // Getters
  int get adminRecNo => _adminRecNo ?? 0;
  String get adminName => _adminName;
  String get email => _email;
  String get username => _username;

  // Set Data (Call this upon Login)
  void setAdminData(Map<String, dynamic> userData) {
    // Mapping keys based on your sp_UserLogin SQL aliases
    _adminRecNo = userData['UserID'];
    _username = userData['Username'] ?? '';
    _adminName = userData['DisplayName'] ?? 'Admin'; // SQL 'FullName' mapped to 'DisplayName'
    _email = userData['ContactEmail'] ?? 'No Email';

    notifyListeners();
  }

  // Clear Data (Call this upon Logout)
  void clearData() {
    _adminRecNo = null;
    _adminName = 'Admin';
    _email = '';
    _username = '';
    notifyListeners();
  }
}