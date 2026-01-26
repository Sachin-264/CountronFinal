// lib/AdminService/data_api_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../widgets/constants.dart';

class DataApiService {
  // lib/AdminService/data_api_service.dart

  String _getApiBaseUrl() {
    return "${ApiConstants.baseUrl}/get_data_by_time.php";
  }

  /// Fetches time-series data for selected channels within a time range.
  Future<List<Map<String, dynamic>>> fetchChannelData({
    required int deviceRecNo,
    required String startDate,
    required String endDate,
    required String channelRecNos,
  }) async {
    final uri = Uri.parse(_getApiBaseUrl());

    // Note: We use api_test.php for the GET_DATA_BY_TIME action.

    final body = jsonEncode({
      "action": "GET_DATA_BY_TIME",
      "DeviceRecNo": deviceRecNo,
      "StartDate": startDate,
      "EndDate": endDate,
      "ChannelRecNos": channelRecNos,
    });

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success' && result['data'] is List) {
          // Return the list of raw data points
          return List<Map<String, dynamic>>.from(result['data']);
        } else {
          throw Exception(result['error'] ?? 'API responded with success: false');
        }
      } else {
        throw Exception('Server error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching channel data: $e');
      rethrow;
    }
  }
}