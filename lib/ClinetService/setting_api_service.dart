// [UPDATE] lib/ClinetService/setting_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../widgets/constants.dart';

class SettingsApiService {
  String _getApiUrl() {
    return "${ApiConstants.baseUrl}/api_device_settings.php";
  }

  // NOTE: The provided PHP script does not handle 'Action' or 'FETCH_BRANDING'.
  // This call might fail unless a different PHP file handles branding,
  // or if the PHP script is updated to handle sendc for branding.
  Future<Map<String, dynamic>?> fetchSettings(int recNo) async {
    // Keeping old logic for now, as the new PHP doesn't appear to support branding fetch.
    return _callApi({"RecNo": recNo, "Action": "FETCH_BRANDING"});
  }

  // NOTE: The provided PHP script does not have UPDATE logic.
  // Saving will likely fail until the backend supports it.
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

  // UPDATED: Uses sendc: 1
  Future<Map<String, dynamic>?> fetchAlarmSettings(int recNo) async {
    // sendc: 1 returns "Limits", "frequency", "sfreq"
    final data = await _callApi({"device": recNo, "sendc": 1});

    if (data != null && data.containsKey('Limits')) {
      // The PHP returns Limits as a JSON object (or array).
      // We return it directly assuming it contains keys like 'AlarmEmails', 'IsEnabled'
      // that match your UI.
      if (data['Limits'] is Map<String, dynamic>) {
        return data['Limits'];
      } else if (data['Limits'] is List) {
        // Handle case where empty limits might return []
        return {};
      }
    }
    return data;
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

  // UPDATED: Uses sendc: 1
  Future<Map<String, dynamic>?> fetchFrequencySettings(int recNo) async {
    // sendc: 1 returns "frequency" and "sfreq" at the root level
    final data = await _callApi({"device": recNo, "sendc": 1});

    if (data != null) {
      // Map PHP keys (lowercase) to UI keys (PascalCase)
      // Note: PHP returns integers for frequency. Your UI expects Strings (e.g., '30 sec').
      // You may need to map these integers to strings here if the UI dropdowns break.
      return {
        "SFreq": data['sfreq']?.toString(),     // Mapping 'sfreq' -> 'SFreq'
        "TFreq": data['frequency']?.toString(), // Mapping 'frequency' -> 'TFreq'
      };
    }
    return null;
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

  // UPDATED: customized for api_device_settings.php response structure
  Future<Map<String, dynamic>?> _callApi(Map<String, dynamic> body) async {
    try {
      final response = await http.post(Uri.parse(_getApiUrl()), body: jsonEncode(body));

      // print("API Response: ${response.body}"); // Debugging

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // The new PHP script uses integer status 200, not string "success"
        if (result['status'] == 200 || result['status'] == 'success') {
          // The new PHP script puts data at root (e.g. result['Limits']),
          // NOT in a 'data' wrapper. We return the whole result so methods can pick fields.
          return result;
        }
      }
    } catch (e) {
      print("API Error: $e");
    }
    return null;
  }

  // Keeping this for Save methods, assuming they might hit a different logic
  // or will be updated later.
  Future<bool> _callApiBool(Map<String, dynamic> body) async {
    try {
      final response = await http.post(Uri.parse(_getApiUrl()), body: jsonEncode(body));
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