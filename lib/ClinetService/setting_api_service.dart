import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/constants.dart';

class SettingsApiService {
  String _getApiUrl() {
    return "${ApiConstants.baseUrl}/api_device_settings.php";
  }

  // Generic helper to parse the 'data' key from the response
  Future<Map<String, dynamic>?> _callApiAndGetData(Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(_getApiUrl()),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // Check for success (PHP returns 'success' string or 200 int)
        if (result['status'] == 'success' || result['status'] == 200) {
          // 🛠️ FIX: Return the nested 'data' object, not the root
          if (result.containsKey('data')) {
            return result['data'];
          }
        }
      } else {
        print("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      print("API Connection Error: $e");
    }
    return null;
  }

  // 1. Fetch Branding/Device Settings
  Future<Map<String, dynamic>?> fetchSettings(int recNo) async {
    // Sends standard FETCH action (default in PHP else block)
    return _callApiAndGetData({
      "RecNo": recNo,
      "Action": "FETCH"
    });
  }

  // 2. Fetch Alarm Settings
  Future<Map<String, dynamic>?> fetchAlarmSettings(int recNo) async {
    // 🛠️ FIX: Send 'FETCH_ALARM' action to match PHP logic
    final data = await _callApiAndGetData({
      "RecNo": recNo,
      "Action": "FETCH_ALARM"
    });

    return data;
  }

  // 3. Fetch Frequency Settings
  Future<Map<String, dynamic>?> fetchFrequencySettings(int recNo) async {
    // 🛠️ FIX: Send 'FETCH_FREQ' action to match PHP logic
    final data = await _callApiAndGetData({
      "RecNo": recNo,
      "Action": "FETCH_FREQ"
    });

    return data;
  }

  // ==========================================
  // SAVE METHODS (Ensure these match PHP inputs)
  // ==========================================

  Future<bool> saveSettings({
    required int recNo,
    required String companyName,
    required String address,
    required String logoPath,
  }) async {
    return _callApiBool({
      "RecNo": recNo,
      "Action": "UPDATE",
      "CompanyName": companyName,
      "Address": address,
      "Logo": logoPath,
    });
  }

  Future<bool> saveAlarmSettings({
    required int recNo,
    required String emails,
    required String frequency,
    required int delayMinutes,
    required bool isEnabled,
  }) async {
    return _callApiBool({
      "RecNo": recNo,
      "Action": "UPDATE_ALARM",
      "AlarmEmails": emails,
      "AlertFrequency": frequency,
      "AlertDelayMinutes": delayMinutes,
      "IsEnabled": isEnabled ? 1 : 0
    });
  }

  Future<bool> saveFrequencySettings({
    required int recNo,
    required String sFreq,
    required String tFreq,
  }) async {
    return _callApiBool({
      "RecNo": recNo,
      "Action": "UPDATE_FREQ",
      "SFreq": sFreq,
      "TFreq": tFreq,
    });
  }

  Future<bool> _callApiBool(Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(_getApiUrl()),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['status'] == 'success' || result['status'] == 200;
      }
    } catch (e) {
      print("API Error: $e");
    }
    return false;
  }
}