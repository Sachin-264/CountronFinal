import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../widgets/constants.dart';

class SettingsApiService {
  String _getApiUrl() {
    return "${ApiConstants.baseUrl}/api_device_settings.php";
  }

  Future<Map<String, dynamic>?> fetchSettings(int recNo) async {
    return _callApi({"RecNo": recNo, "Action": "FETCH_BRANDING"});
  }

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

  Future<Map<String, dynamic>?> fetchAlarmSettings(int recNo) async {
    return _callApi({"RecNo": recNo, "Action": "FETCH_ALARM"});
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

  Future<Map<String, dynamic>?> fetchFrequencySettings(int recNo) async {
    return _callApi({"RecNo": recNo, "Action": "FETCH_FREQ"});
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

  Future<Map<String, dynamic>?> _callApi(Map<String, dynamic> body) async {
    try {
      final response = await http.post(Uri.parse(_getApiUrl()), body: jsonEncode(body));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') return result['data'];
      }
    } catch (e) {
      print("API Error: $e");
    }
    return null;
  }

  Future<bool> _callApiBool(Map<String, dynamic> body) async {
    try {
      final response = await http.post(Uri.parse(_getApiUrl()), body: jsonEncode(body));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['status'] == 'success';
      }
    } catch (e) {
      print("API Error: $e");
    }
    return false;
  }
}